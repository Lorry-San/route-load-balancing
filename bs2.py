#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
拼好线 (PinHaoXian) - Multi-Line Load Balancer
A powerful load balancer supporting up to 6 lines with TCP/UDP protocols
Author: Lorry-San
GitHub: https://github.com/Lorry-San/route-load-balancing
License: MIT
"""

import socket
import threading
import time
import argparse
import sys
import os
import signal
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

__version__ = "1.0.0"

class MultiLineLoadBalancer:
    def __init__(self, listen_host, listen_port, targets, small_packet_size=1024, 
                 mode='auto', protocols=['tcp', 'udp'], daemon=False, log_file=None, primary=1):
        """
        多线路负载均衡器（支持最多6条线路）
        :param targets: 目标服务器列表 [(host, port), ...]
        :param daemon: 是否后台运行
        :param log_file: 日志文件路径
        :param primary: 默认主线路编号（1-6）
        """
        self.listen_host = listen_host
        self.listen_port = listen_port
        self.targets = targets
        self.target_count = len(targets)
        self.small_packet_size = small_packet_size
        self.mode = mode
        self.protocols = [p.lower() for p in protocols]
        self.daemon = daemon
        
        # 设置主线路（转换为索引，从0开始）
        self.primary_index = primary - 1
        if self.primary_index < 0 or self.primary_index >= self.target_count:
            self.primary_index = 0
        
        # 设置日志
        self.setup_logging(log_file, daemon)
        
        # UDP会话管理
        self.client_sessions = {}
        self.session_lock = threading.Lock()
        self.session_timeout = 60
        
        # TCP连接计数器 - 从主线路开始
        self.tcp_connection_count = self.primary_index
        self.tcp_count_lock = threading.Lock()
        
        # UDP连接计数器 - 从主线路开始
        self.udp_connection_count = self.primary_index
        self.udp_count_lock = threading.Lock()
        
        # 统计信息 - 为每个目标创建统计
        self.stats = {
            'tcp': {
                'total': 0,
                'small_packets': 0,
                'large_packets': 0,
                'targets': [0] * self.target_count
            },
            'udp': {
                'total': 0,
                'small_packets': 0,
                'large_packets': 0,
                'targets': [0] * self.target_count
            }
        }
        self.stats_lock = threading.Lock()
        
        # 服务器socket
        self.tcp_server = None
        self.udp_server = None
        self.running = True
        
        # PID文件
        self.pid_file = f'/tmp/loadbalancer_{self.listen_port}.pid'

    def setup_logging(self, log_file, daemon):
        """设置日志系统"""
        if daemon:
            # 后台模式：写入日志文件
            if not log_file:
                log_file = f'/var/log/loadbalancer_{self.listen_port}.log'
            
            # 创建日志目录
            log_dir = os.path.dirname(log_file)
            if log_dir and not os.path.exists(log_dir):
                try:
                    os.makedirs(log_dir)
                except:
                    log_file = f'/tmp/loadbalancer_{self.listen_port}.log'
            
            # 配置文件日志处理器（带轮转）
            handler = RotatingFileHandler(
                log_file, 
                maxBytes=10*1024*1024,  # 10MB
                backupCount=5
            )
            formatter = logging.Formatter(
                '%(asctime)s [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            handler.setFormatter(formatter)
            
            logging.basicConfig(
                level=logging.INFO,
                handlers=[handler]
            )
            self.logger = logging.getLogger(__name__)
            self.logger.info(f"日志文件: {log_file}")
        else:
            # 前台模式：输出到控制台
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            self.logger = logging.getLogger(__name__)

    def log(self, message, level='info'):
        """统一日志接口"""
        if level == 'info':
            self.logger.info(message)
        elif level == 'error':
            self.logger.error(message)
        elif level == 'warning':
            self.logger.warning(message)
        elif level == 'debug':
            self.logger.debug(message)

    def get_next_tcp_target(self):
        """TCP轮询获取目标"""
        with self.tcp_count_lock:
            self.tcp_connection_count += 1
            target_index = self.tcp_connection_count % self.target_count
            return self.targets[target_index], target_index

    def get_next_udp_target(self):
        """UDP轮询获取目标"""
        with self.udp_count_lock:
            self.udp_connection_count += 1
            target_index = self.udp_connection_count % self.target_count
            return self.targets[target_index], target_index

    def update_stats(self, protocol, target_index, is_small_packet=None):
        """更新统计"""
        with self.stats_lock:
            self.stats[protocol]['total'] += 1
            self.stats[protocol]['targets'][target_index] += 1
            if is_small_packet is not None:
                self.stats[protocol]['small_packets' if is_small_packet else 'large_packets'] += 1

    # ========== TCP处理方法 ==========
    def handle_tcp_client(self, client_socket, client_address):
        """处理TCP连接"""
        target_socket = None
        try:
            # 接收第一个数据包
            client_socket.settimeout(5)
            first_data = client_socket.recv(8192)
            client_socket.settimeout(None)
            
            if not first_data:
                client_socket.close()
                return
            
            packet_size = len(first_data)
            
            # 根据模式选择目标
            if self.mode == 'auto':
                target, target_index = self.get_next_tcp_target()
                is_small = packet_size < self.small_packet_size
                self.log(f"[TCP轮询#{(self.tcp_connection_count % self.target_count) + 1}] {client_address} -> T{target_index+1}:{target} ({packet_size}B)")
            else:
                if packet_size < self.small_packet_size:
                    target, target_index = self.targets[self.primary_index], self.primary_index
                    is_small = True
                    self.log(f"[TCP小包] {client_address} -> T{target_index+1}:{target} ({packet_size}B)")
                else:
                    target, target_index = self.get_next_tcp_target()
                    is_small = False
                    self.log(f"[TCP大包] {client_address} -> T{target_index+1}:{target} ({packet_size}B)")
            
            self.update_stats('tcp', target_index, is_small)
            
            # 连接目标并转发
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect(target)
            target_socket.sendall(first_data)
            
            # 双向转发
            def forward(src, dst, direction):
                try:
                    while True:
                        data = src.recv(8192)
                        if not data:
                            break
                        dst.sendall(data)
                except:
                    pass
                finally:
                    try:
                        src.shutdown(socket.SHUT_RDWR)
                    except:
                        pass
            
            t1 = threading.Thread(target=forward, args=(client_socket, target_socket, "C->T"))
            t2 = threading.Thread(target=forward, args=(target_socket, client_socket, "T->C"))
            t1.daemon = t2.daemon = True
            t1.start()
            t2.start()
            t1.join()
            t2.join()
            
        except Exception as e:
            self.log(f"[TCP错误] {client_address}: {e}", 'error')
        finally:
            try:
                if client_socket:
                    client_socket.close()
                if target_socket:
                    target_socket.close()
            except:
                pass

    # ========== UDP处理方法 ==========
    def get_udp_target(self, client_address, packet_size):
        """获取UDP客户端对应的目标（保持会话一致性）"""
        with self.session_lock:
            if client_address in self.client_sessions:
                target, target_index, _ = self.client_sessions[client_address]
                self.client_sessions[client_address] = (target, target_index, time.time())
                return target, target_index, False
            
            # 新会话
            if self.mode == 'auto':
                target, target_index = self.get_next_udp_target()
                is_small = packet_size < self.small_packet_size
            else:
                if packet_size < self.small_packet_size:
                    target, target_index = self.targets[self.primary_index], self.primary_index
                    is_small = True
                else:
                    target, target_index = self.get_next_udp_target()
                    is_small = False
            
            self.client_sessions[client_address] = (target, target_index, time.time())
            return target, target_index, True

    def handle_udp_packet(self, data, client_address):
        """处理UDP数据包"""
        try:
            packet_size = len(data)
            target, target_index, is_new = self.get_udp_target(client_address, packet_size)
            
            if is_new:
                is_small = packet_size < self.small_packet_size
                self.update_stats('udp', target_index, is_small)
                if self.mode == 'auto':
                    self.log(f"[UDP轮询#{(self.udp_connection_count % self.target_count) + 1}] {client_address} -> T{target_index+1}:{target} ({packet_size}B)")
                else:
                    self.log(f"[UDP{'小' if is_small else '大'}包] {client_address} -> T{target_index+1}:{target} ({packet_size}B)")
            else:
                self.update_stats('udp', target_index)
            
            # 转发
            forward_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            forward_socket.sendto(data, target)
            
            # 接收响应
            def handle_response():
                try:
                    forward_socket.settimeout(5)
                    resp_data, _ = forward_socket.recvfrom(65535)
                    if self.udp_server:
                        self.udp_server.sendto(resp_data, client_address)
                except:
                    pass
                finally:
                    forward_socket.close()
            
            threading.Thread(target=handle_response, daemon=True).start()
            
        except Exception as e:
            self.log(f"[UDP错误] {client_address}: {e}", 'error')

    def clean_udp_sessions(self):
        """清理过期UDP会话"""
        while self.running:
            time.sleep(30)
            current_time = time.time()
            with self.session_lock:
                expired = [
                    client for client, (_, _, last_seen) in self.client_sessions.items()
                    if current_time - last_seen > self.session_timeout
                ]
                for client in expired:
                    del self.client_sessions[client]

    def print_stats(self):
        """打印统计"""
        while self.running:
            time.sleep(60)  # 每分钟统计一次
            with self.stats_lock:
                msg = f"\n{'='*60}\n"
                msg += f"负载均衡统计 [模式:{self.mode}] - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                msg += f"{'='*60}\n"
                
                for proto in self.protocols:
                    total = self.stats[proto]['total']
                    if total > 0:
                        msg += f"\n{proto.upper()}协议:\n"
                        msg += f"  总连接/包数: {total}\n"
                        
                        for i in range(self.target_count):
                            count = self.stats[proto]['targets'][i]
                            percentage = (count / total * 100) if total > 0 else 0
                            primary_mark = " [主线路]" if i == self.primary_index else ""
                            msg += f"  目标{i+1} {self.targets[i]}: {count} ({percentage:.1f}%){primary_mark}\n"
                        
                        if self.mode == 'size':
                            msg += f"  小包: {self.stats[proto]['small_packets']}\n"
                            msg += f"  大包: {self.stats[proto]['large_packets']}\n"
                
                if 'udp' in self.protocols:
                    msg += f"\nUDP活跃会话: {len(self.client_sessions)}\n"
                
                msg += f"{'='*60}\n"
                self.log(msg)

    def start_tcp_server(self):
        """启动TCP服务"""
        try:
            self.tcp_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.tcp_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.tcp_server.bind((self.listen_host, self.listen_port))
            self.tcp_server.listen(100)
            self.log(f"[TCP] 监听在 {self.listen_host}:{self.listen_port}")
            
            while self.running:
                try:
                    self.tcp_server.settimeout(1.0)
                    client_socket, client_address = self.tcp_server.accept()
                    threading.Thread(
                        target=self.handle_tcp_client,
                        args=(client_socket, client_address),
                        daemon=True
                    ).start()
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        self.log(f"[TCP错误] {e}", 'error')
                    break
        except Exception as e:
            self.log(f"[TCP启动错误] {e}", 'error')
        finally:
            if self.tcp_server:
                self.tcp_server.close()

    def start_udp_server(self):
        """启动UDP服务"""
        try:
            self.udp_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.udp_server.bind((self.listen_host, self.listen_port))
            self.log(f"[UDP] 监听在 {self.listen_host}:{self.listen_port}")
            
            # 启动会话清理线程
            threading.Thread(target=self.clean_udp_sessions, daemon=True).start()
            
            while self.running:
                try:
                    self.udp_server.settimeout(1.0)
                    data, client_address = self.udp_server.recvfrom(65535)
                    threading.Thread(
                        target=self.handle_udp_packet,
                        args=(data, client_address),
                        daemon=True
                    ).start()
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        self.log(f"[UDP错误] {e}", 'error')
                    break
        except Exception as e:
            self.log(f"[UDP启动错误] {e}", 'error')
        finally:
            if self.udp_server:
                self.udp_server.close()

    def write_pid_file(self):
        """写入PID文件"""
        try:
            with open(self.pid_file, 'w') as f:
                f.write(str(os.getpid()))
            self.log(f"PID文件: {self.pid_file}")
        except Exception as e:
            self.log(f"无法写入PID文件: {e}", 'error')

    def remove_pid_file(self):
        """删除PID文件"""
        try:
            if os.path.exists(self.pid_file):
                os.remove(self.pid_file)
        except:
            pass

    def daemonize(self):
        """后台化进程"""
        try:
            # 第一次fork
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError as e:
            self.log(f"第一次fork失败: {e}", 'error')
            sys.exit(1)
        
        # 脱离父进程
        os.chdir('/')
        os.setsid()
        os.umask(0)
        
        # 第二次fork
        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError as e:
            self.log(f"第二次fork失败: {e}", 'error')
            sys.exit(1)
        
        # 重定向标准文件描述符
        sys.stdout.flush()
        sys.stderr.flush()
        
        with open('/dev/null', 'r') as f:
            os.dup2(f.fileno(), sys.stdin.fileno())
        with open('/dev/null', 'a+') as f:
            os.dup2(f.fileno(), sys.stdout.fileno())
        with open('/dev/null', 'a+') as f:
            os.dup2(f.fileno(), sys.stderr.fileno())

    def signal_handler(self, signum, frame):
        """信号处理"""
        self.log(f"收到信号 {signum}，正在关闭...")
        self.running = False

    def start(self):
        """启动负载均衡器"""
        # 后台化
        if self.daemon:
            self.daemonize()
        
        # 写入PID文件
        self.write_pid_file()
        
        # 注册信号处理
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        mode_desc = "自动轮询分流" if self.mode == 'auto' else f"按包大小分流(阈值:{self.small_packet_size}B)"
        protocols_desc = " + ".join([p.upper() for p in self.protocols])
        
        msg = f"\n{'='*60}\n"
        msg += f"拼好线 v{__version__} - 多线路负载均衡器\n"
        msg += f"{'='*60}\n"
        msg += f"[协议] {protocols_desc}\n"
        msg += f"[监听] {self.listen_host}:{self.listen_port}\n"
        msg += f"[模式] {mode_desc}\n"
        msg += f"[线路数] {self.target_count}\n"
        msg += f"[主线路] 目标{self.primary_index + 1}\n"
        for i, target in enumerate(self.targets):
            primary_mark = " [主线路-单线程默认]" if i == self.primary_index else ""
            msg += f"[目标{i+1}] {target}{primary_mark}\n"
        if self.mode == 'size':
            msg += f"[规则] 包 < {self.small_packet_size}B -> 主线路(目标{self.primary_index + 1})\n"
            msg += f"[规则] 包 >= {self.small_packet_size}B -> 轮询所有线路\n"
        else:
            msg += f"[规则] 所有连接自动轮询分配（从主线路开始）\n"
        msg += f"[后台] {'是' if self.daemon else '否'}\n"
        msg += f"{'='*60}\n"
        self.log(msg)
        
        # 启动统计线程
        threading.Thread(target=self.print_stats, daemon=True).start()
        
        # 启动服务器线程
        server_threads = []
        
        if 'tcp' in self.protocols:
            tcp_thread = threading.Thread(target=self.start_tcp_server)
            tcp_thread.daemon = True
            tcp_thread.start()
            server_threads.append(tcp_thread)
        
        if 'udp' in self.protocols:
            udp_thread = threading.Thread(target=self.start_udp_server)
            udp_thread.daemon = True
            udp_thread.start()
            server_threads.append(udp_thread)
        
        try:
            # 等待所有服务器线程
            for thread in server_threads:
                thread.join()
        except KeyboardInterrupt:
            self.log("收到中断信号，正在关闭...")
            self.running = False
            time.sleep(1)
        finally:
            self.remove_pid_file()
            self.log("负载均衡器已关闭")


def parse_target(target_str, default_host):
    """解析目标地址"""
    if ':' in target_str:
        host, port = target_str.rsplit(':', 1)
        return (host, int(port))
    else:
        return (default_host, int(target_str))


def read_pid(pid_file):
    """读取PID文件"""
    try:
        with open(pid_file, 'r') as f:
            return int(f.read().strip())
    except:
        return None


def stop_daemon(listen_port):
    """停止后台进程"""
    pid_file = f'/tmp/loadbalancer_{listen_port}.pid'
    pid = read_pid(pid_file)
    
    if pid is None:
        print(f"未找到运行中的负载均衡器（端口 {listen_port}）")
        return False
    
    try:
        os.kill(pid, signal.SIGTERM)
        print(f"正在停止负载均衡器（PID: {pid}）...")
        
        # 等待进程结束
        for _ in range(10):
            try:
                os.kill(pid, 0)
                time.sleep(0.5)
            except OSError:
                print("负载均衡器已停止")
                return True
        
        # 强制杀死
        try:
            os.kill(pid, signal.SIGKILL)
            print("强制停止负载均衡器")
        except:
            pass
        
        return True
    except OSError as e:
        print(f"停止失败: {e}")
        return False


def show_status(listen_port):
    """显示运行状态"""
    pid_file = f'/tmp/loadbalancer_{listen_port}.pid'
    pid = read_pid(pid_file)
    
    if pid is None:
        print(f"负载均衡器（端口 {listen_port}）未运行")
        return
    
    try:
        os.kill(pid, 0)
        print(f"负载均衡器正在运行")
        print(f"  PID: {pid}")
        print(f"  PID文件: {pid_file}")
        print(f"  日志文件: /var/log/loadbalancer_{listen_port}.log")
        print(f"\n查看日志: tail -f /var/log/loadbalancer_{listen_port}.log")
    except OSError:
        print(f"负载均衡器（端口 {listen_port}）未运行（PID文件过期）")
        try:
            os.remove(pid_file)
        except:
            pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='拼好线 - 多线路负载均衡器 v' + __version__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
使用示例:
  # 2线路自动轮询（前台运行）
  %(prog)s -l 40001 -t 40002 40003
  
  # 3线路，指定从目标2开始轮询（后台运行）
  %(prog)s -l 40001 -t 40002 40003 40004 --primary 2 -d
  
  # 6线路最大配置
  %(prog)s -l 40001 -t 40002 40003 40004 40005 40006 40007 -d
  
  # 只转发TCP
  %(prog)s -l 40001 -t 40002 40003 -p tcp
  
  # 按包大小分流
  %(prog)s -l 40001 -t 40002 40003 -m size -s 1024 -d
  
  # 完整地址配置
  %(prog)s -l 40001 -t 192.168.1.10:40002 192.168.1.11:40003 -d
  
  # 停止后台进程
  %(prog)s --stop -l 40001
  
  # 查看运行状态
  %(prog)s --status -l 40001

GitHub: https://github.com/Lorry-San/route-load-balancing
        '''
    )
    
    parser.add_argument('-l', '--listen-port', type=int, 
                        help='监听端口')
    parser.add_argument('-t', '--targets', nargs='+', 
                        help='目标端口或host:port列表（2-6个）')
    parser.add_argument('-p', '--protocol', 
                        choices=['tcp', 'udp', 'both'], 
                        default='both',
                        help='协议类型: tcp, udp, both（默认both）')
    parser.add_argument('-m', '--mode', choices=['auto', 'size'], default='auto',
                        help='分流模式: auto=自动轮询(默认), size=按包大小')
    parser.add_argument('-s', '--size', type=int, default=1024, 
                        help='小包阈值（默认1024字节）')
    parser.add_argument('-H', '--host', default='0.0.0.0', 
                        help='监听地址（默认0.0.0.0）')
    parser.add_argument('--target-host', default='127.0.0.1', 
                        help='目标主机（默认127.0.0.1）')
    parser.add_argument('--primary', type=int, default=1,
                        help='主线路编号（1-6，默认1）')
    parser.add_argument('-d', '--daemon', action='store_true',
                        help='后台运行')
    parser.add_argument('--log-file', 
                        help='日志文件路径')
    parser.add_argument('--stop', action='store_true',
                        help='停止后台进程')
    parser.add_argument('--status', action='store_true',
                        help='查看运行状态')
    parser.add_argument('-v', '--version', action='version',
                        version=f'%(prog)s {__version__}')
    
    args = parser.parse_args()
    
    # 停止服务
    if args.stop:
        if not args.listen_port:
            print("错误: 需要指定 -l/--listen-port")
            sys.exit(1)
        stop_daemon(args.listen_port)
        sys.exit(0)
    
    # 查看状态
    if args.status:
        if not args.listen_port:
            print("错误: 需要指定 -l/--listen-port")
            sys.exit(1)
        show_status(args.listen_port)
        sys.exit(0)
    
    # 启动服务
    if not args.listen_port or not args.targets:
        parser.print_help()
        sys.exit(1)
    
    # 验证目标数量
    if len(args.targets) < 2 or len(args.targets) > 6:
        print("错误: 目标数量必须在2-6之间")
        sys.exit(1)
    
    # 验证主线路编号
    if args.primary < 1 or args.primary > len(args.targets):
        print(f"错误: 主线路编号必须在1-{len(args.targets)}之间")
        sys.exit(1)
    
    # 确定协议
    if args.protocol == 'both':
        protocols = ['tcp', 'udp']
    else:
        protocols = [args.protocol]
    
    try:
        # 解析所有目标
        targets = [parse_target(t, args.target_host) for t in args.targets]
        
        balancer = MultiLineLoadBalancer(
            listen_host=args.host,
            listen_port=args.listen_port,
            targets=targets,
            small_packet_size=args.size,
            mode=args.mode,
            protocols=protocols,
            daemon=args.daemon,
            log_file=args.log_file,
            primary=args.primary
        )
        
        if args.daemon:
            print(f"正在后台启动拼好线负载均衡器...")
            print(f"端口: {args.listen_port}")
            print(f"线路数: {len(targets)}")
            print(f"主线路: 目标{args.primary}")
            print(f"日志文件: {args.log_file or f'/var/log/loadbalancer_{args.listen_port}.log'}")
            print(f"PID文件: /tmp/loadbalancer_{args.listen_port}.pid")
            print(f"\n使用以下命令管理:")
            print(f"  查看状态: bs2 --status -l {args.listen_port}")
            print(f"  停止服务: bs2 --stop -l {args.listen_port}")
            print(f"  查看日志: tail -f {args.log_file or f'/var/log/loadbalancer_{args.listen_port}.log'}")
        
        balancer.start()
        
    except ValueError as e:
        print(f"错误: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"错误: {e}")
        sys.exit(1)

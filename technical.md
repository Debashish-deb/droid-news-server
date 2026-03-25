-------------------------------------
Translated Report (Full Report Below)
-------------------------------------
Process:             Runner [56609]
Path:                /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Runner
Identifier:          com.bd.bdnewsreader
Version:             1.0.1 (24)
Code Type:           ARM-64 (Native)
Role:                Foreground
Parent Process:      launchd_sim [13944]
Coalition:           com.apple.CoreSimulator.SimDevice.84AEE392-9A81-4F9C-A10F-2732ED430B5C [131703]
Responsible Process: SimulatorTrampoline [5650]
User ID:             501

Date/Time:           2026-02-20 17:33:03.3456 +0200
Launch Time:         2026-02-20 17:32:47.6238 +0200
Hardware Model:      Mac15,6
OS Version:          macOS 26.3 (25D125)
Release Type:        User

Crash Reporter Key:  54E29178-DFF7-CFDB-7C21-D44531D415C3
Incident Identifier: 8ACB86BE-A9C2-4161-A700-BBFC3352F32E

Sleep/Wake UUID:       938EBD62-A06E-463D-93E5-2C34BEB42273

Time Awake Since Boot: 68000 seconds
Time Since Wake:       9730 seconds

System Integrity Protection: enabled

Triggered by Thread: 0, Dispatch Queue: com.apple.main-thread

Exception Type:    EXC_CRASH (SIGABRT)
Exception Codes:   0x0000000000000000, 0x0000000000000000

Termination Reason:  Namespace SIGNAL, Code 6, Abort trap: 6
Terminating Process: Runner [56609]


Last Exception Backtrace:
0   CoreFoundation                	       0x1804f71c4 __exceptionPreprocess + 160
1   libobjc.A.dylib               	       0x18009c094 objc_exception_throw + 72
2   CoreFoundation                	       0x1804f70e0 -[NSException initWithCoder:] + 0
3   GoogleSignIn                  	       0x102d16dac -[GIDSignIn signInWithOptions:] + 444 (GIDSignIn.m:592)
4   GoogleSignIn                  	       0x102d1565c -[GIDSignIn signInWithPresentingViewController:hint:additionalScopes:completion:] + 208 (GIDSignIn.m:282)
5   Runner.debug.dylib            	       0x104477bd0 -[FLTGoogleSignInPlugin signInWithHint:additionalScopes:completion:] + 176
6   Runner.debug.dylib            	       0x104476ca0 -[FLTGoogleSignInPlugin signInWithCompletion:] + 776
7   Runner.debug.dylib            	       0x10447bf8c __FSIGoogleSignInApiSetup_block_invoke.119 + 192
8   Flutter                       	       0x10f7585c8 __48-[FlutterBasicMessageChannel setMessageHandler:]_block_invoke + 160
9   Flutter                       	       0x10f27a5d8 invocation function for block in flutter::PlatformMessageHandlerIos::HandlePlatformMessage(std::__fl::unique_ptr<flutter::PlatformMessage, std::__fl::default_delete<flutter::PlatformMessage>>) + 108
10  libdispatch.dylib             	       0x1801c07a8 _dispatch_call_block_and_release + 24
11  libdispatch.dylib             	       0x1801db4b0 _dispatch_client_callout + 12
12  libdispatch.dylib             	       0x1801f74a0 <deduplicated_symbol> + 24
13  libdispatch.dylib             	       0x1801d031c _dispatch_main_queue_drain + 1184
14  libdispatch.dylib             	       0x1801cfe6c _dispatch_main_queue_callback_4CF + 40
15  CoreFoundation                	       0x180455ed8 __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__ + 12
16  CoreFoundation                	       0x1804550b0 __CFRunLoopRun + 1884
17  CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
18  GraphicsServices              	       0x192a669bc GSEventRunModal + 116
19  UIKitCore                     	       0x186348574 -[UIApplication _run] + 772
20  UIKitCore                     	       0x18634c79c UIApplicationMain + 124
21  UIKitCore                     	       0x18557f2d0 0x18519e000 + 4068048
22  Runner.debug.dylib            	       0x103a16f60 static UIApplicationDelegate.main() + 128
23  Runner.debug.dylib            	       0x103a16ed0 static AppDelegate.$main() + 44
24  Runner.debug.dylib            	       0x103a1700c __debug_main_executable_dylib_entry_point + 28
25  ???                           	       0x1028513d0 ???
26  dyld                          	       0x102920d54 start + 7184

Kernel Triage:
VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter
VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter
VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter
VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter
VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter


Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
0   libsystem_kernel.dylib        	       0x1051c885c __pthread_kill + 8
1   libsystem_pthread.dylib       	       0x1054b62a8 pthread_kill + 264
2   libsystem_c.dylib             	       0x1801b5a0c __abort + 108
3   libsystem_c.dylib             	       0x1801b59a0 abort + 112
4   libc++abi.dylib               	       0x18030326c __abort_message + 128
5   libc++abi.dylib               	       0x1802f31a4 demangling_terminate_handler() + 268
6   libobjc.A.dylib               	       0x180077218 _objc_terminate() + 124
7   FirebaseCrashlytics           	       0x102d7bd20 FIRCLSTerminateHandler() + 404 (FIRCLSException.mm:466)
8   libc++abi.dylib               	       0x180302758 std::__terminate(void (*)()) + 12
9   libc++abi.dylib               	       0x1803057c0 __cxxabiv1::failed_throw(__cxxabiv1::__cxa_exception*) + 32
10  libc++abi.dylib               	       0x1803057a0 __cxa_throw + 88
11  libobjc.A.dylib               	       0x18009c1cc objc_exception_throw + 384
12  CoreFoundation                	       0x1804f6d64 -[NSException raise] + 12
13  Runner.debug.dylib            	       0x104476dfc -[FLTGoogleSignInPlugin signInWithCompletion:] + 1124
14  Runner.debug.dylib            	       0x10447bf8c __FSIGoogleSignInApiSetup_block_invoke.119 + 192
15  Flutter                       	       0x10f7585c8 __48-[FlutterBasicMessageChannel setMessageHandler:]_block_invoke + 160
16  Flutter                       	       0x10f27a5d8 invocation function for block in flutter::PlatformMessageHandlerIos::HandlePlatformMessage(std::__fl::unique_ptr<flutter::PlatformMessage, std::__fl::default_delete<flutter::PlatformMessage>>) + 108
17  libdispatch.dylib             	       0x1801c07a8 _dispatch_call_block_and_release + 24
18  libdispatch.dylib             	       0x1801db4b0 _dispatch_client_callout + 12
19  libdispatch.dylib             	       0x1801f74a0 <deduplicated_symbol> + 24
20  libdispatch.dylib             	       0x1801d031c _dispatch_main_queue_drain + 1184
21  libdispatch.dylib             	       0x1801cfe6c _dispatch_main_queue_callback_4CF + 40
22  CoreFoundation                	       0x180455ed8 __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__ + 12
23  CoreFoundation                	       0x1804550b0 __CFRunLoopRun + 1884
24  CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
25  GraphicsServices              	       0x192a669bc GSEventRunModal + 116
26  UIKitCore                     	       0x186348574 -[UIApplication _run] + 772
27  UIKitCore                     	       0x18634c79c UIApplicationMain + 124
28  UIKitCore                     	       0x18557f2d0 0x18519e000 + 4068048
29  Runner.debug.dylib            	       0x103a16f60 static UIApplicationDelegate.main() + 128
30  Runner.debug.dylib            	       0x103a16ed0 static AppDelegate.$main() + 44
31  Runner.debug.dylib            	       0x103a1700c __debug_main_executable_dylib_entry_point + 28
32  ???                           	       0x1028513d0 ???
33  dyld                          	       0x102920d54 start + 7184

Thread 1:

Thread 2:

Thread 3:: com.apple.uikit.eventfetch-thread
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   Foundation                    	       0x18110be48 -[NSRunLoop(NSRunLoop) runMode:beforeDate:] + 208
8   Foundation                    	       0x18110c068 -[NSRunLoop(NSRunLoop) runUntilDate:] + 60
9   UIKitCore                     	       0x18609fc50 -[UIEventFetcher threadMain] + 392
10  Foundation                    	       0x181132d14 __NSThread__start__ + 716
11  libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
12  libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 4:

Thread 5:: io.flutter.1.raster
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   Flutter                       	       0x10f2aee74 fml::MessageLoopDarwin::Run() + 92
8   Flutter                       	       0x10f2a793c fml::MessageLoopImpl::DoRun() + 44
9   Flutter                       	       0x10f2ad51c std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()() + 184
10  Flutter                       	       0x10f2ad1e0 fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*) + 36
11  libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
12  libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 6:: io.flutter.1.io
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   Flutter                       	       0x10f2aee74 fml::MessageLoopDarwin::Run() + 92
8   Flutter                       	       0x10f2a793c fml::MessageLoopImpl::DoRun() + 44
9   Flutter                       	       0x10f2ad51c std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()() + 184
10  Flutter                       	       0x10f2ad1e0 fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*) + 36
11  libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
12  libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 7:: io.flutter.1.profiler
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   Flutter                       	       0x10f2aee74 fml::MessageLoopDarwin::Run() + 92
8   Flutter                       	       0x10f2a793c fml::MessageLoopImpl::DoRun() + 44
9   Flutter                       	       0x10f2ad51c std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()() + 184
10  Flutter                       	       0x10f2ad1e0 fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*) + 36
11  libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
12  libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 8:: io.worker.1
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6a74 _pthread_cond_wait + 976
2   Flutter                       	       0x10f27fdc4 std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&) + 24
3   Flutter                       	       0x10f2a40e0 fml::ConcurrentMessageLoop::WorkerMain() + 140
4   Flutter                       	       0x10f2a4788 void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*) + 192
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 9:: io.worker.2
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6a74 _pthread_cond_wait + 976
2   Flutter                       	       0x10f27fdc4 std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&) + 24
3   Flutter                       	       0x10f2a40e0 fml::ConcurrentMessageLoop::WorkerMain() + 140
4   Flutter                       	       0x10f2a4788 void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*) + 192
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 10:: io.worker.3
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6a74 _pthread_cond_wait + 976
2   Flutter                       	       0x10f27fdc4 std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&) + 24
3   Flutter                       	       0x10f2a40e0 fml::ConcurrentMessageLoop::WorkerMain() + 140
4   Flutter                       	       0x10f2a4788 void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*) + 192
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 11:: io.worker.4
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6a74 _pthread_cond_wait + 976
2   Flutter                       	       0x10f27fdc4 std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&) + 24
3   Flutter                       	       0x10f2a40e0 fml::ConcurrentMessageLoop::WorkerMain() + 140
4   Flutter                       	       0x10f2a4788 void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*) + 192
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 12:: dart:io EventHandler
0   libsystem_kernel.dylib        	       0x1051c665c kevent + 8
1   Flutter                       	       0x10f716180 dart::bin::EventHandlerImplementation::EventHandlerEntry(unsigned long) + 304
2   Flutter                       	       0x10f732258 dart::bin::ThreadStart(void*) + 92
3   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
4   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 13:: Dart Profiler ThreadInterrupter
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6a74 _pthread_cond_wait + 976
2   Flutter                       	       0x10f77fb3c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 128
3   Flutter                       	       0x10f8e7a90 dart::ThreadInterrupter::ThreadMain(unsigned long) + 336
4   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 14:: Dart Profiler SampleBlockProcessor
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f89ecc0 dart::SampleBlockProcessor::ThreadMain(unsigned long) + 220
4   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
5   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
6   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 15:: DartWorker
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f7dfa8c dart::MutatorThreadPool::OnEnterIdleLocked(dart::MutexLocker*, dart::ThreadPool::Worker*) + 156
4   Flutter                       	       0x10f8e86ac dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*) + 124
5   Flutter                       	       0x10f8e8990 dart::ThreadPool::Worker::Main(unsigned long) + 116
6   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
7   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
8   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 16:: caulk.messenger.shared:17
0   libsystem_kernel.dylib        	       0x1051c0aec semaphore_wait_trap + 8
1   caulk                         	       0x1ba9f1cb0 caulk::semaphore::timed_wait(double) + 220
2   caulk                         	       0x1ba9f9998 caulk::concurrent::details::worker_thread::run() + 28
3   caulk                         	       0x1ba9f9a0c void* caulk::thread_proxy<std::__1::tuple<caulk::thread::attributes, void (caulk::concurrent::details::worker_thread::*)(), std::__1::tuple<caulk::concurrent::details::worker_thread*>>>(void*) + 48
4   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
5   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 17:: caulk.messenger.shared:high
0   libsystem_kernel.dylib        	       0x1051c0aec semaphore_wait_trap + 8
1   caulk                         	       0x1ba9f1cb0 caulk::semaphore::timed_wait(double) + 220
2   caulk                         	       0x1ba9f9998 caulk::concurrent::details::worker_thread::run() + 28
3   caulk                         	       0x1ba9f9a0c void* caulk::thread_proxy<std::__1::tuple<caulk::thread::attributes, void (caulk::concurrent::details::worker_thread::*)(), std::__1::tuple<caulk::concurrent::details::worker_thread*>>>(void*) + 48
4   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
5   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 18:

Thread 19:

Thread 20:

Thread 21:

Thread 22:: com.google.firebase.crashlytics.MachExceptionServer
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   FirebaseCrashlytics           	       0x102d8b878 FIRCLSMachExceptionReadMessage + 80 (FIRCLSMachException.c:196)
5   FirebaseCrashlytics           	       0x102d8b7b0 FIRCLSMachExceptionServer + 52 (FIRCLSMachException.c:172)
6   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
7   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 23:: DartWorker
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f8e8830 dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*) + 512
4   Flutter                       	       0x10f8e8990 dart::ThreadPool::Worker::Main(unsigned long) + 116
5   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
6   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
7   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 24:: DartWorker
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f8e8830 dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*) + 512
4   Flutter                       	       0x10f8e8990 dart::ThreadPool::Worker::Main(unsigned long) + 116
5   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
6   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
7   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 25:: com.apple.NSURLConnectionLoader
0   libsystem_kernel.dylib        	       0x1051c0b70 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x1051d190c mach_msg2_internal + 72
2   libsystem_kernel.dylib        	       0x1051c8c10 mach_msg_overwrite + 480
3   libsystem_kernel.dylib        	       0x1051c0ee4 mach_msg + 20
4   CoreFoundation                	       0x180455c04 __CFRunLoopServiceMachPort + 156
5   CoreFoundation                	       0x180454dbc __CFRunLoopRun + 1128
6   CoreFoundation                	       0x18044fcec _CFRunLoopRunSpecificWithOptions + 496
7   CFNetwork                     	       0x184eccd6c +[__CFN_CoreSchedulingSetRunnable _run:] + 368
8   Foundation                    	       0x181132d14 __NSThread__start__ + 716
9   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
10  libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 26:: DartWorker
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f8e8830 dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*) + 512
4   Flutter                       	       0x10f8e8990 dart::ThreadPool::Worker::Main(unsigned long) + 116
5   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
6   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
7   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8

Thread 27:: DartWorker
0   libsystem_kernel.dylib        	       0x1051c4020 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x1054b6aa0 _pthread_cond_wait + 1020
2   Flutter                       	       0x10f77fb2c dart::ConditionVariable::WaitMicros(dart::Mutex*, long long) + 112
3   Flutter                       	       0x10f8e8830 dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*) + 512
4   Flutter                       	       0x10f8e8990 dart::ThreadPool::Worker::Main(unsigned long) + 116
5   Flutter                       	       0x10f899cc0 dart::ThreadStart(void*) + 208
6   libsystem_pthread.dylib       	       0x1054b65ac _pthread_start + 104
7   libsystem_pthread.dylib       	       0x1054b1998 thread_start + 8


Thread 0 crashed with ARM Thread State (64-bit):
    x0: 0x0000000000000000   x1: 0x0000000000000000   x2: 0x0000000000000000   x3: 0x0000000000000000
    x4: 0x0000000000000000   x5: 0x0000000000989680   x6: 0x000000000000006e   x7: 0x0000000000000000
    x8: 0x00000001029c5e40   x9: 0xa116654a0c9d6c21  x10: 0x00000000000003e8  x11: 0x0000010000000000
   x12: 0x00000000fffffffd  x13: 0x0000000000000000  x14: 0x0000000000000000  x15: 0x0000000000000000
   x16: 0x0000000000000148  x17: 0x0000000000000002  x18: 0x0000000000000000  x19: 0x0000000000000006
   x20: 0x0000000000000103  x21: 0x00000001029c5f20  x22: 0x00000001f26c8000  x23: 0x00000001f26c5900
   x24: 0x00000001f26c5900  x25: 0x0000600001769140  x26: 0x0000000000000000  x27: 0x0000000000000000
   x28: 0x0000000000000114   fp: 0x000000016d65b860   lr: 0x00000001054b62a8
    sp: 0x000000016d65b840   pc: 0x00000001051c885c cpsr: 0x40001000
   far: 0x0000000000000000  esr: 0x56000080 (Syscall)

Binary Images:
       0x102918000 -        0x1029b7fff dyld (*) <bc4db5f4-1c64-3706-8006-73b78c3e1f1a> /usr/lib/dyld
       0x1027a0000 -        0x1027a3fff com.bd.bdnewsreader (1.0.1) <7c18d5b1-7beb-36ef-90a5-7d5383b356f4> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Runner
       0x103a10000 -        0x10460ffff Runner.debug.dylib (*) <583cd91b-b5c1-327f-a127-283cad12f20b> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Runner.debug.dylib
       0x102a4c000 -        0x102a73fff org.cocoapods.AppAuth (1.7.6) <3d931d83-3ab5-3ba5-bd0d-fc911479ce24> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/AppAuth.framework/AppAuth
       0x102aa4000 -        0x102ac7fff org.cocoapods.AppCheckCore (11.2.0) <f8ab13d8-ccfe-3ca8-b5b2-a85d2a107ee4> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/AppCheckCore.framework/AppCheckCore
       0x1027f0000 -        0x102803fff org.cocoapods.FBLPromises (2.4.0) <5b1da8bb-942e-3b5f-b535-85086af24c39> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FBLPromises.framework/FBLPromises
       0x102824000 -        0x10282ffff org.cocoapods.FirebaseABTesting (12.8.0) <b0e558cf-79e0-308a-b3ed-fdfa5b9f2a88> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseABTesting.framework/FirebaseABTesting
       0x1027d0000 -        0x1027d3fff org.cocoapods.FirebaseAppCheckInterop (12.8.0) <fffbd269-8ac1-39ec-8ac7-f3bd601f7206> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseAppCheckInterop.framework/FirebaseAppCheckInterop
       0x102eb0000 -        0x10303bfff org.cocoapods.FirebaseAuth (12.8.0) <d1af881a-fce8-39b9-8352-95c4fdd62cb5> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseAuth.framework/FirebaseAuth
       0x102afc000 -        0x102afffff org.cocoapods.FirebaseAuthInterop (12.8.0) <10ffbc20-53a0-3bae-b189-4531516bdabf> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseAuthInterop.framework/FirebaseAuthInterop
       0x102b48000 -        0x102b5bfff org.cocoapods.FirebaseCore (12.8.0) <3b8908ae-3e54-3c63-8d75-ac4dab148575> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseCore.framework/FirebaseCore
       0x102b10000 -        0x102b13fff org.cocoapods.FirebaseCoreExtension (12.8.0) <34987ade-f561-3891-9790-9dfe36ec206c> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseCoreExtension.framework/FirebaseCoreExtension
       0x102bf8000 -        0x102c1ffff org.cocoapods.FirebaseCoreInternal (12.8.0) <51f0025f-890a-3c40-bfe7-8f95ffa086da> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseCoreInternal.framework/FirebaseCoreInternal
       0x102d68000 -        0x102dd7fff org.cocoapods.FirebaseCrashlytics (12.8.0) <0d335795-a4d7-3564-8df8-401e42e9c951> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseCrashlytics.framework/FirebaseCrashlytics
       0x1033a4000 -        0x10340bfff org.cocoapods.FirebaseFirestore (12.8.0) <9b4ee40f-7762-32b5-83d8-4f12dd732c79> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseFirestore.framework/FirebaseFirestore
       0x105e2c000 -        0x1063b3fff org.cocoapods.FirebaseFirestoreInternal (12.8.0) <122cbd3f-7c6f-3bab-b52c-3dde06fd6efd> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseFirestoreInternal.framework/FirebaseFirestoreInternal
       0x102c70000 -        0x102c8bfff org.cocoapods.FirebaseInstallations (12.8.0) <2f398c4b-b451-3bc7-89ee-8ba10778fc7c> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseInstallations.framework/FirebaseInstallations
       0x103264000 -        0x1032a7fff org.cocoapods.FirebaseMessaging (12.8.0) <a55b0624-fd08-3d7c-8717-f52bb628de71> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseMessaging.framework/FirebaseMessaging
       0x1032f0000 -        0x103333fff org.cocoapods.FirebasePerformance (12.8.0) <6015943b-721a-3b19-8925-3983996cb0ac> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebasePerformance.framework/FirebasePerformance
       0x1034e0000 -        0x10351ffff org.cocoapods.FirebaseRemoteConfig (12.8.0) <6cfe5162-dfd9-3da1-a65d-c86afd0f4cf9> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseRemoteConfig.framework/FirebaseRemoteConfig
       0x102b7c000 -        0x102b83fff org.cocoapods.FirebaseRemoteConfigInterop (12.8.0) <580a486d-2fec-36fc-bda7-9f459e595334> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseRemoteConfigInterop.framework/FirebaseRemoteConfigInterop
       0x10356c000 -        0x103597fff org.cocoapods.FirebaseSessions (12.8.0) <b138badb-584f-354d-9ee4-1287e87e4397> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseSessions.framework/FirebaseSessions
       0x1035f4000 -        0x10363ffff org.cocoapods.FirebaseSharedSwift (12.8.0) <7b2c20ab-3cfe-3064-9437-7b9a015f31bb> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseSharedSwift.framework/FirebaseSharedSwift
       0x103778000 -        0x1037cffff org.cocoapods.FirebaseStorage (12.8.0) <d79b18f8-16ac-35b9-b1af-abd6453ce8df> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/FirebaseStorage.framework/FirebaseStorage
       0x102b9c000 -        0x102bbffff org.cocoapods.GTMAppAuth (4.1.1) <925a13bb-e68d-3012-af08-8a1b3093b09a> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/GTMAppAuth.framework/GTMAppAuth
       0x1036a4000 -        0x1036f7fff org.cocoapods.GTMSessionFetcher (3.5.0) <a8280994-1893-3278-881c-85ff838dc9f2> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/GTMSessionFetcher.framework/GTMSessionFetcher
       0x103848000 -        0x103877fff org.cocoapods.GoogleDataTransport (10.1.0) <7599b43d-5f07-33d1-9b42-20bf11de5c70> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/GoogleDataTransport.framework/GoogleDataTransport
       0x102d08000 -        0x102d2bfff org.cocoapods.GoogleSignIn (8.0.0) <e4dc0a8b-7541-3291-acf2-d59a68e63de3> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/GoogleSignIn.framework/GoogleSignIn
       0x102e5c000 -        0x102e7ffff org.cocoapods.GoogleUtilities (8.1.0) <339e3061-c702-3d18-9a04-c80a415f39a6> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/GoogleUtilities.framework/GoogleUtilities
       0x10373c000 -        0x103747fff org.cocoapods.OrderedSet (6.0.3) <a06b1866-6fe9-3382-85a5-85a38fa26942> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/OrderedSet.framework/OrderedSet
       0x1038b0000 -        0x1038c7fff org.cocoapods.Promises (2.4.0) <e78ef7da-bc68-3776-81ad-10ac20d54f2f> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/Promises.framework/Promises
       0x102b24000 -        0x102b27fff org.cocoapods.RecaptchaInterop (101.0.0) <33be8149-4570-30ea-b90b-113f330fff47> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/RecaptchaInterop.framework/RecaptchaInterop
       0x104d9c000 -        0x104f07fff org.cocoapods.absl (1.20240722.0) <2d9b9e7d-4622-35ac-a5b4-c070a0b485a4> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/absl.framework/absl
       0x102cd4000 -        0x102cdbfff org.cocoapods.audio-service (0.0.1) <0a39789d-d762-392b-b31b-854e14942435> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/audio_service.framework/audio_service
       0x10391c000 -        0x10392bfff org.cocoapods.audio-session (0.0.1) <f32be535-2609-394d-a92c-fbba219a0f0f> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/audio_session.framework/audio_session
       0x1039a0000 -        0x1039bffff org.cocoapods.audioplayers-darwin (0.0.1) <8e771bb3-3f93-30e0-9db4-e9b829ddb28c> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/audioplayers_darwin.framework/audioplayers_darwin
       0x1038f0000 -        0x1038fbfff org.cocoapods.connectivity-plus (0.0.1) <21cbf6ac-62fd-38a3-9bc7-d5cf76dbfe43> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/connectivity_plus.framework/connectivity_plus
       0x1027b8000 -        0x1027bffff org.cocoapods.device-info-plus (0.0.1) <b9c06550-4da0-3cae-887e-67943acf0cab> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/device_info_plus.framework/device_info_plus
       0x102cb4000 -        0x102cbbfff org.cocoapods.flutter-haptic-feedback (0.0.1) <e13ddc03-50f8-3c7a-b849-a29af1d0617e> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/flutter_haptic_feedback.framework/flutter_haptic_feedback
       0x1054f8000 -        0x1056affff org.cocoapods.flutter-inappwebview-ios (0.0.1) <4fabfd5d-6774-3c55-83af-bc2921ede8d9> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/flutter_inappwebview_ios.framework/flutter_inappwebview_ios
       0x103970000 -        0x10397ffff org.cocoapods.flutter-local-notifications (0.0.1) <ea7bae8f-e044-3a34-a78d-8794253ea3bd> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/flutter_local_notifications.framework/flutter_local_notifications
       0x103384000 -        0x103387fff org.cocoapods.flutter-native-splash (2.4.3) <2775540b-db2c-392d-889a-0c8e39851553> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/flutter_native_splash.framework/flutter_native_splash
       0x104a3c000 -        0x104a53fff org.cocoapods.flutter-secure-storage-darwin (10.0.0) <d1793e9f-4f2d-3319-996a-23cb4949acd7> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/flutter_secure_storage_darwin.framework/flutter_secure_storage_darwin
       0x1049f4000 -        0x1049fffff org.cocoapods.fluttertoast (0.0.2) <bd64a034-ef25-3244-91e1-a7b04d606ea5> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/fluttertoast.framework/fluttertoast
       0x102cf0000 -        0x102cf7fff org.cocoapods.geocoding-ios (1.0.5) <f386ba3f-fd1f-3413-9033-94924b4e4e99> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/geocoding_ios.framework/geocoding_ios
       0x104a18000 -        0x104a23fff org.cocoapods.geolocator-apple (1.2.0) <32a92996-006f-318b-9c0a-a572b8f9c00f> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/geolocator_apple.framework/geolocator_apple
       0x109ec8000 -        0x10ab63fff org.cocoapods.grpc (1.69.0) <528c4828-1e4a-3f92-846a-5a05a836a2d5> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/grpc.framework/grpc
       0x1058b0000 -        0x10597bfff org.cocoapods.grpcpp (1.69.0) <047ad4fb-e048-332a-b748-63a1d94879e7> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/grpcpp.framework/grpcpp
       0x104abc000 -        0x104ad3fff org.cocoapods.image-picker-ios (0.0.1) <2e2eb92e-189e-3d73-b34e-97853205d201> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/image_picker_ios.framework/image_picker_ios
       0x104bdc000 -        0x104c3bfff org.cocoapods.in-app-purchase-storekit (0.0.1) <052e20cf-189d-3134-a464-7efb8f770bcc> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/in_app_purchase_storekit.framework/in_app_purchase_storekit
       0x104a80000 -        0x104a87fff org.cocoapods.integration-test (0.0.1) <d9160f91-1b58-3dd6-b31e-5353c4031167> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/integration_test.framework/integration_test
       0x104b2c000 -        0x104b43fff org.cocoapods.just-audio (0.0.1) <60fccbec-7331-3241-b68a-24ae0936fca1> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/just_audio.framework/just_audio
       0x105258000 -        0x1052bffff org.cocoapods.leveldb (1.22.6) <531e15c9-3d38-3006-b987-b3fae6b25bc6> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/leveldb.framework/leveldb
       0x104cc0000 -        0x104cd7fff org.cocoapods.local-auth-darwin (0.0.1) <a38ca77e-9a0a-31fb-96d2-6288ad877660> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/local_auth_darwin.framework/local_auth_darwin
       0x1039f8000 -        0x1039fffff org.cocoapods.nanopb (3.30910.0) <e4ea8e47-8890-3897-ac86-b5cfbd2064f3> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/nanopb.framework/nanopb
       0x107580000 -        0x107747fff org.cocoapods.openssl-grpc (0.0.37) <650a7f0b-fbcb-3db7-8571-f9616bcf614e> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/openssl_grpc.framework/openssl_grpc
       0x10395c000 -        0x10395ffff org.cocoapods.package-info-plus (0.4.5) <f6a68753-25ae-3ef6-beea-593905c03ab4> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/package_info_plus.framework/package_info_plus
       0x104a9c000 -        0x104aa3fff org.cocoapods.path-provider-foundation (0.0.1) <ea8c98e7-1781-39f7-a113-bdf2e9fbad0b> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/path_provider_foundation.framework/path_provider_foundation
       0x104b60000 -        0x104b67fff org.cocoapods.share-plus (0.0.1) <0ce48ef1-347c-3035-a8be-d4a43856f68f> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/share_plus.framework/share_plus
       0x104d04000 -        0x104d17fff org.cocoapods.shared-preferences-foundation (0.0.1) <ebc70aab-d774-3a4b-baa1-4d22df5a04a1> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/shared_preferences_foundation.framework/shared_preferences_foundation
       0x104d40000 -        0x104d5ffff org.cocoapods.sqflite-darwin (0.0.4) <657ec0a3-2a7b-32ee-a7ea-b41e7569f287> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/sqflite_darwin.framework/sqflite_darwin
       0x107260000 -        0x1073b7fff org.cocoapods.sqlite3 (3.51.1) <3857bfbd-444d-3a0d-9e82-5a77177f6b63> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/sqlite3.framework/sqlite3
       0x103944000 -        0x103947fff org.cocoapods.sqlite3-flutter-libs (0.0.1) <75f4e2af-8243-349a-9ae3-3378dd0a3dbb> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/sqlite3_flutter_libs.framework/sqlite3_flutter_libs
       0x105140000 -        0x105153fff org.cocoapods.url-launcher-ios (0.0.1) <baebcffb-9f43-3d3f-80ad-388d04f6249b> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/url_launcher_ios.framework/url_launcher_ios
       0x10517c000 -        0x105197fff org.cocoapods.video-player-avfoundation (0.0.1) <26c532e2-e0e0-3fb2-a917-b2f08822c8c6> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/video_player_avfoundation.framework/video_player_avfoundation
       0x104b7c000 -        0x104b83fff org.cocoapods.wakelock-plus (0.0.1) <b309161c-f9b0-3bcc-8a70-cce0a7be860d> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/wakelock_plus.framework/wakelock_plus
       0x1078a4000 -        0x10794ffff org.cocoapods.webview-flutter-wkwebview (0.0.1) <e2d3fd42-8f40-3a3c-9ea9-2dbcf4bc8417> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/webview_flutter_wkwebview.framework/webview_flutter_wkwebview
       0x105410000 -        0x10544ffff org.cocoapods.workmanager-apple (0.0.1) <bd3bc9dc-7905-3546-9e3b-f34220b8d842> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/workmanager_apple.framework/workmanager_apple
       0x10f210000 -        0x111097fff io.flutter.flutter (1.0) <4c4c4472-5555-3144-a129-5b766c61c004> /Users/USER/Library/Developer/CoreSimulator/Devices/84AEE392-9A81-4F9C-A10F-2732ED430B5C/data/Containers/Bundle/Application/6D9F0007-7E46-4A60-95AB-3891BC2AEE67/Runner.app/Frameworks/Flutter.framework/Flutter
       0x104b98000 -        0x104b9ffff libsystem_platform.dylib (*) <9463fc06-cc7c-38e8-ad3c-1b9f2617df53> /usr/lib/system/libsystem_platform.dylib
       0x1051c0000 -        0x1051fbfff libsystem_kernel.dylib (*) <1a15cc38-efcc-34ea-a261-cfd370f4b557> /usr/lib/system/libsystem_kernel.dylib
       0x1054b0000 -        0x1054bffff libsystem_pthread.dylib (*) <b1095734-2a4d-3e8c-839e-b10ae9598d61> /usr/lib/system/libsystem_pthread.dylib
       0x105be8000 -        0x105bf3fff libobjc-trampolines.dylib (*) <997b234d-5c24-3e21-97d6-33b6853818c0> /Volumes/VOLUME/*/libobjc-trampolines.dylib
       0x180141000 -        0x1801be2c3 libsystem_c.dylib (*) <e0197e7b-9d61-356a-90b7-4be1270b82d5> /Volumes/VOLUME/*/libsystem_c.dylib
       0x1802f2000 -        0x18030a56f libc++abi.dylib (*) <0fc14bd2-2110-348c-8278-7a6fb63a7000> /Volumes/VOLUME/*/libc++abi.dylib
       0x180070000 -        0x1800ad297 libobjc.A.dylib (*) <880f8664-cd53-3912-bdd5-5e3159295f7d> /Volumes/VOLUME/*/libobjc.A.dylib
       0x1803c3000 -        0x1807df37f com.apple.CoreFoundation (6.9) <4f6d050d-95ee-3a95-969c-3a98b29df6ff> /Volumes/VOLUME/*/CoreFoundation.framework/CoreFoundation
       0x1801bf000 -        0x1802041bf libdispatch.dylib (*) <ec9ecf10-959d-3da1-a055-6de970159b9d> /Volumes/VOLUME/*/libdispatch.dylib
       0x192a64000 -        0x192a6bdbf com.apple.GraphicsServices (1.0) <4e5b0462-6170-3367-9475-4ff8b8dfe4e6> /Volumes/VOLUME/*/GraphicsServices.framework/GraphicsServices
       0x18519e000 -        0x1873c071f com.apple.UIKitCore (1.0) <196154ff-ba04-33cd-9277-98f9aa0b7499> /Volumes/VOLUME/*/UIKitCore.framework/UIKitCore
               0x0 - 0xffffffffffffffff ??? (*) <00000000-0000-0000-0000-000000000000> ???
       0x18085f000 -        0x1815d18df com.apple.Foundation (6.9) <c153116f-dd31-3fa9-89bb-04b47c1fa83d> /Volumes/VOLUME/*/Foundation.framework/Foundation
       0x1ba9e2000 -        0x1baa085bf com.apple.audio.caulk (1.0) <3e592a6d-e4ae-387e-9f93-b81c874443dc> /Volumes/VOLUME/*/caulk.framework/caulk
       0x184ccc000 -        0x18503e15f com.apple.CFNetwork (1.0) <1bb7d015-7687-34a6-93c8-7cc24655033a> /Volumes/VOLUME/*/CFNetwork.framework/CFNetwork

External Modification Summary:
  Calls made by other processes targeting this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by all processes on this machine:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0

VM Region Summary:
ReadOnly portion of Libraries: Total=2.1G resident=0K(0%) swapped_out_or_unallocated=2.1G(100%)
Writable regions: Total=969.0M written=2291K(0%) resident=2243K(0%) swapped_out=48K(0%) unallocated=966.7M(100%)

                                VIRTUAL   REGION 
REGION TYPE                        SIZE    COUNT (non-coalesced) 
===========                     =======  ======= 
Activity Tracing                   256K        1 
Foundation                          16K        1 
IOSurface                         44.7M        5 
Kernel Alloc Once                   32K        1 
MALLOC                           653.8M      129 
MALLOC guard page                  128K        8 
Mach message                        16K        1 
SQLite page cache                 1664K       13 
STACK GUARD                       56.4M       27 
Stack                             30.4M       31 
VM_ALLOCATE                      251.2M      815 
__DATA                            63.1M     1107 
__DATA_CONST                     133.0M     1128 
__DATA_DIRTY                       139K       13 
__FONT_DATA                        2352        1 
__LINKEDIT                       780.4M       74 
__OBJC_RO                         62.5M        1 
__OBJC_RW                         2771K        1 
__TEXT                             1.3G     1143 
__TPRO_CONST                       148K        2 
dyld private memory                2.2G       20 
mapped file                      200.1M       37 
page table in kernel              2243K        1 
shared memory                       16K        1 
===========                     =======  ======= 
TOTAL                              5.7G     4561 


-----------
Full Report
-----------

{"app_name":"Runner","timestamp":"2026-02-20 17:33:09.00 +0200","app_version":"1.0.1","slice_uuid":"7c18d5b1-7beb-36ef-90a5-7d5383b356f4","build_version":"24","platform":7,"bundleID":"com.bd.bdnewsreader","share_with_app_devs":0,"is_first_party":0,"bug_type":"309","os_version":"macOS 26.3 (25D125)","roots_installed":0,"name":"Runner","incident_id":"8ACB86BE-A9C2-4161-A700-BBFC3352F32E"}
{
  "uptime" : 68000,
  "procRole" : "Foreground",
  "version" : 2,
  "userID" : 501,
  "deployVersion" : 210,
  "modelCode" : "Mac15,6",
  "coalitionID" : 131703,
  "osVersion" : {
    "train" : "macOS 26.3",
    "build" : "25D125",
    "releaseType" : "User"
  },
  "captureTime" : "2026-02-20 17:33:03.3456 +0200",
  "codeSigningMonitor" : 2,
  "incident" : "8ACB86BE-A9C2-4161-A700-BBFC3352F32E",
  "pid" : 56609,
  "translated" : false,
  "cpuType" : "ARM-64",
  "procLaunch" : "2026-02-20 17:32:47.6238 +0200",
  "procStartAbsTime" : 1647653655323,
  "procExitAbsTime" : 1648030845375,
  "procName" : "Runner",
  "procPath" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Runner",
  "bundleInfo" : {"CFBundleShortVersionString":"1.0.1","CFBundleVersion":"24","CFBundleIdentifier":"com.bd.bdnewsreader"},
  "storeInfo" : {"deviceIdentifierForVendor":"9D4662E4-3AE3-55D4-BBDB-2C9E07467C51","thirdParty":true},
  "parentProc" : "launchd_sim",
  "parentPid" : 13944,
  "coalitionName" : "com.apple.CoreSimulator.SimDevice.84AEE392-9A81-4F9C-A10F-2732ED430B5C",
  "crashReporterKey" : "54E29178-DFF7-CFDB-7C21-D44531D415C3",
  "appleIntelligenceStatus" : {"state":"available"},
  "developerMode" : 1,
  "responsiblePid" : 5650,
  "responsibleProc" : "SimulatorTrampoline",
  "codeSigningID" : "com.bd.bdnewsreader",
  "codeSigningTeamID" : "",
  "codeSigningFlags" : 570425857,
  "codeSigningValidationCategory" : 10,
  "codeSigningTrustLevel" : 4294967295,
  "codeSigningAuxiliaryInfo" : 0,
  "instructionByteStream" : {"beforePC":"4wAAVP17v6n9AwCRKeP\/l78DAJH9e8GowANf1sADX9YQKYDSARAA1A==","atPC":"4wAAVP17v6n9AwCRH+P\/l78DAJH9e8GowANf1sADX9ZwCoDSARAA1A=="},
  "bootSessionUUID" : "CE319AC9-985D-4370-AE48-0292716E8205",
  "wakeTime" : 9730,
  "sleepWakeUUID" : "938EBD62-A06E-463D-93E5-2C34BEB42273",
  "sip" : "enabled",
  "exception" : {"codes":"0x0000000000000000, 0x0000000000000000","rawCodes":[0,0],"type":"EXC_CRASH","signal":"SIGABRT"},
  "termination" : {"flags":0,"code":6,"namespace":"SIGNAL","indicator":"Abort trap: 6","byProc":"Runner","byPid":56609},
  "ktriageinfo" : "VM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter\nVM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter\nVM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter\nVM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter\nVM - (arg = 0x3) mach_vm_allocate_kernel failed within call to vm_map_enter\n",
  "extMods" : {"caller":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"system":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"targeted":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"warnings":0},
  "lastExceptionBacktrace" : [{"imageOffset":1262020,"symbol":"__exceptionPreprocess","symbolLocation":160,"imageIndex":76},{"imageOffset":180372,"symbol":"objc_exception_throw","symbolLocation":72,"imageIndex":75},{"imageOffset":1261792,"symbol":"-[NSException initWithCoder:]","symbolLocation":0,"imageIndex":76},{"imageOffset":60844,"sourceLine":592,"sourceFile":"GIDSignIn.m","symbol":"-[GIDSignIn signInWithOptions:]","imageIndex":27,"symbolLocation":444},{"imageOffset":54876,"sourceLine":282,"sourceFile":"GIDSignIn.m","symbol":"-[GIDSignIn signInWithPresentingViewController:hint:additionalScopes:completion:]","imageIndex":27,"symbolLocation":208},{"imageOffset":10910672,"symbol":"-[FLTGoogleSignInPlugin signInWithHint:additionalScopes:completion:]","symbolLocation":176,"imageIndex":2},{"imageOffset":10906784,"symbol":"-[FLTGoogleSignInPlugin signInWithCompletion:]","symbolLocation":776,"imageIndex":2},{"imageOffset":10928012,"symbol":"__FSIGoogleSignInApiSetup_block_invoke.119","symbolLocation":192,"imageIndex":2},{"imageOffset":5539272,"symbol":"__48-[FlutterBasicMessageChannel setMessageHandler:]_block_invoke","symbolLocation":160,"imageIndex":68},{"imageOffset":435672,"symbol":"invocation function for block in flutter::PlatformMessageHandlerIos::HandlePlatformMessage(std::__fl::unique_ptr<flutter::PlatformMessage, std::__fl::default_delete<flutter::PlatformMessage>>)","symbolLocation":108,"imageIndex":68},{"imageOffset":6056,"symbol":"_dispatch_call_block_and_release","symbolLocation":24,"imageIndex":77},{"imageOffset":115888,"symbol":"_dispatch_client_callout","symbolLocation":12,"imageIndex":77},{"imageOffset":230560,"symbol":"<deduplicated_symbol>","symbolLocation":24,"imageIndex":77},{"imageOffset":70428,"symbol":"_dispatch_main_queue_drain","symbolLocation":1184,"imageIndex":77},{"imageOffset":69228,"symbol":"_dispatch_main_queue_callback_4CF","symbolLocation":40,"imageIndex":77},{"imageOffset":601816,"symbol":"__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__","symbolLocation":12,"imageIndex":76},{"imageOffset":598192,"symbol":"__CFRunLoopRun","symbolLocation":1884,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":10684,"symbol":"GSEventRunModal","symbolLocation":116,"imageIndex":78},{"imageOffset":18523508,"symbol":"-[UIApplication _run]","symbolLocation":772,"imageIndex":79},{"imageOffset":18540444,"symbol":"UIApplicationMain","symbolLocation":124,"imageIndex":79},{"imageOffset":4068048,"imageIndex":79},{"imageOffset":28512,"sourceFile":"\/<compiler-generated>","symbol":"static UIApplicationDelegate.main()","symbolLocation":128,"imageIndex":2},{"imageOffset":28368,"sourceFile":"\/<compiler-generated>","symbol":"static AppDelegate.$main()","symbolLocation":44,"imageIndex":2},{"imageOffset":28684,"sourceFile":"\/<compiler-generated>","symbol":"__debug_main_executable_dylib_entry_point","symbolLocation":28,"imageIndex":2},{"imageOffset":4337243088,"imageIndex":80},{"imageOffset":36180,"symbol":"start","symbolLocation":7184,"imageIndex":0}],
  "faultingThread" : 0,
  "threads" : [{"triggered":true,"id":3010916,"threadState":{"x":[{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":10000000},{"value":110},{"value":0},{"value":4338769472,"symbolLocation":0,"symbol":"_main_thread"},{"value":11607576458307660833},{"value":1000},{"value":1099511627776},{"value":4294967293},{"value":0},{"value":0},{"value":0},{"value":328},{"value":2},{"value":0},{"value":6},{"value":259},{"value":4338769696,"symbolLocation":224,"symbol":"_main_thread"},{"value":8362164224,"symbolLocation":0,"symbol":"objc_debug_taggedpointer_classes"},{"value":8362154240,"symbolLocation":0,"symbol":"_dispatch_main_q"},{"value":8362154240,"symbolLocation":0,"symbol":"_dispatch_main_q"},{"value":105553140814144},{"value":0},{"value":0},{"value":276}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383793832},"cpsr":{"value":1073745920},"fp":{"value":6130350176},"sp":{"value":6130350144},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380723292,"matchesCrashFrame":1},"far":{"value":0}},"queue":"com.apple.main-thread","frames":[{"imageOffset":34908,"symbol":"__pthread_kill","symbolLocation":8,"imageIndex":70},{"imageOffset":25256,"symbol":"pthread_kill","symbolLocation":264,"imageIndex":71},{"imageOffset":477708,"symbol":"__abort","symbolLocation":108,"imageIndex":73},{"imageOffset":477600,"symbol":"abort","symbolLocation":112,"imageIndex":73},{"imageOffset":70252,"symbol":"__abort_message","symbolLocation":128,"imageIndex":74},{"imageOffset":4516,"symbol":"demangling_terminate_handler()","symbolLocation":268,"imageIndex":74},{"imageOffset":29208,"symbol":"_objc_terminate()","symbolLocation":124,"imageIndex":75},{"imageOffset":81184,"sourceLine":466,"sourceFile":"FIRCLSException.mm","symbol":"FIRCLSTerminateHandler()","imageIndex":13,"symbolLocation":404},{"imageOffset":67416,"symbol":"std::__terminate(void (*)())","symbolLocation":12,"imageIndex":74},{"imageOffset":79808,"symbol":"__cxxabiv1::failed_throw(__cxxabiv1::__cxa_exception*)","symbolLocation":32,"imageIndex":74},{"imageOffset":79776,"symbol":"__cxa_throw","symbolLocation":88,"imageIndex":74},{"imageOffset":180684,"symbol":"objc_exception_throw","symbolLocation":384,"imageIndex":75},{"imageOffset":1260900,"symbol":"-[NSException raise]","symbolLocation":12,"imageIndex":76},{"imageOffset":10907132,"symbol":"-[FLTGoogleSignInPlugin signInWithCompletion:]","symbolLocation":1124,"imageIndex":2},{"imageOffset":10928012,"symbol":"__FSIGoogleSignInApiSetup_block_invoke.119","symbolLocation":192,"imageIndex":2},{"imageOffset":5539272,"symbol":"__48-[FlutterBasicMessageChannel setMessageHandler:]_block_invoke","symbolLocation":160,"imageIndex":68},{"imageOffset":435672,"symbol":"invocation function for block in flutter::PlatformMessageHandlerIos::HandlePlatformMessage(std::__fl::unique_ptr<flutter::PlatformMessage, std::__fl::default_delete<flutter::PlatformMessage>>)","symbolLocation":108,"imageIndex":68},{"imageOffset":6056,"symbol":"_dispatch_call_block_and_release","symbolLocation":24,"imageIndex":77},{"imageOffset":115888,"symbol":"_dispatch_client_callout","symbolLocation":12,"imageIndex":77},{"imageOffset":230560,"symbol":"<deduplicated_symbol>","symbolLocation":24,"imageIndex":77},{"imageOffset":70428,"symbol":"_dispatch_main_queue_drain","symbolLocation":1184,"imageIndex":77},{"imageOffset":69228,"symbol":"_dispatch_main_queue_callback_4CF","symbolLocation":40,"imageIndex":77},{"imageOffset":601816,"symbol":"__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__","symbolLocation":12,"imageIndex":76},{"imageOffset":598192,"symbol":"__CFRunLoopRun","symbolLocation":1884,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":10684,"symbol":"GSEventRunModal","symbolLocation":116,"imageIndex":78},{"imageOffset":18523508,"symbol":"-[UIApplication _run]","symbolLocation":772,"imageIndex":79},{"imageOffset":18540444,"symbol":"UIApplicationMain","symbolLocation":124,"imageIndex":79},{"imageOffset":4068048,"imageIndex":79},{"imageOffset":28512,"sourceFile":"\/<compiler-generated>","symbol":"static UIApplicationDelegate.main()","symbolLocation":128,"imageIndex":2},{"imageOffset":28368,"sourceFile":"\/<compiler-generated>","symbol":"static AppDelegate.$main()","symbolLocation":44,"imageIndex":2},{"imageOffset":28684,"sourceFile":"\/<compiler-generated>","symbol":"__debug_main_executable_dylib_entry_point","symbolLocation":28,"imageIndex":2},{"imageOffset":4337243088,"imageIndex":80},{"imageOffset":36180,"symbol":"start","symbolLocation":7184,"imageIndex":0}]},{"id":3010978,"frames":[],"threadState":{"x":[{"value":6130921472},{"value":7171},{"value":6130384896},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6130921472},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3010981,"frames":[],"threadState":{"x":[{"value":6132641792},{"value":6403},{"value":6132105216},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6132641792},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011007,"name":"com.apple.uikit.eventfetch-thread","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":64884070940672},{"value":0},{"value":64884070940672},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":15107},{"value":3072},{"value":18446744073709551569},{"value":2},{"value":0},{"value":4294967295},{"value":2},{"value":64884070940672},{"value":0},{"value":64884070940672},{"value":6133210504},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":6133210352},"sp":{"value":6133210272},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":76},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":9096776,"symbol":"-[NSRunLoop(NSRunLoop) runMode:beforeDate:]","symbolLocation":208,"imageIndex":81},{"imageOffset":9097320,"symbol":"-[NSRunLoop(NSRunLoop) runUntilDate:]","symbolLocation":60,"imageIndex":81},{"imageOffset":15735888,"symbol":"-[UIEventFetcher threadMain]","symbolLocation":392,"imageIndex":79},{"imageOffset":9256212,"symbol":"__NSThread__start__","symbolLocation":716,"imageIndex":81},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011008,"frames":[],"threadState":{"x":[{"value":6133788672},{"value":13571},{"value":6133252096},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6133788672},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011018,"name":"io.flutter.1.raster","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":124257698840576},{"value":0},{"value":124257698840576},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":28931},{"value":3072},{"value":18446744073709551569},{"value":4398046512130},{"value":0},{"value":4294967295},{"value":2},{"value":124257698840576},{"value":0},{"value":124257698840576},{"value":6135930888},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":6135930736},"sp":{"value":6135930656},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":76},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":650868,"symbol":"fml::MessageLoopDarwin::Run()","symbolLocation":92,"imageIndex":68},{"imageOffset":620860,"symbol":"fml::MessageLoopImpl::DoRun()","symbolLocation":44,"imageIndex":68},{"imageOffset":644380,"symbol":"std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()()","symbolLocation":184,"imageIndex":68},{"imageOffset":643552,"symbol":"fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*)","symbolLocation":36,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011019,"name":"io.flutter.1.io","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":119859652329472},{"value":0},{"value":119859652329472},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":27907},{"value":3072},{"value":18446744073709551569},{"value":2},{"value":0},{"value":4294967295},{"value":2},{"value":119859652329472},{"value":0},{"value":119859652329472},{"value":6138077192},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":6138077040},"sp":{"value":6138076960},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":76},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":650868,"symbol":"fml::MessageLoopDarwin::Run()","symbolLocation":92,"imageIndex":68},{"imageOffset":620860,"symbol":"fml::MessageLoopImpl::DoRun()","symbolLocation":44,"imageIndex":68},{"imageOffset":644380,"symbol":"std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()()","symbolLocation":184,"imageIndex":68},{"imageOffset":643552,"symbol":"fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*)","symbolLocation":36,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011020,"name":"io.flutter.1.profiler","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":108864536051712},{"value":0},{"value":108864536051712},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":25347},{"value":3072},{"value":18446744073709551569},{"value":2},{"value":0},{"value":4294967295},{"value":2},{"value":108864536051712},{"value":0},{"value":108864536051712},{"value":6140223496},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":6140223344},"sp":{"value":6140223264},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":76},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":650868,"symbol":"fml::MessageLoopDarwin::Run()","symbolLocation":92,"imageIndex":68},{"imageOffset":620860,"symbol":"fml::MessageLoopImpl::DoRun()","symbolLocation":44,"imageIndex":68},{"imageOffset":644380,"symbol":"std::__fl::__function::__func<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0, std::__fl::allocator<fml::Thread::Thread(std::__fl::function<void (fml::Thread::ThreadConfig const&)> const&, fml::Thread::ThreadConfig const&)::$_0>, void ()>::operator()()","symbolLocation":184,"imageIndex":68},{"imageOffset":643552,"symbol":"fml::ThreadHandle::ThreadHandle(std::__fl::function<void ()>&&)::$_0::__invoke(void*)","symbolLocation":36,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011021,"name":"io.worker.1","threadState":{"x":[{"value":4},{"value":0},{"value":1280},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6140800488},{"value":0},{"value":256},{"value":1099511628034},{"value":1099511628034},{"value":256},{"value":0},{"value":1099511628032},{"value":305},{"value":53},{"value":0},{"value":4425018216},{"value":4425018280},{"value":6140801248},{"value":0},{"value":0},{"value":1280},{"value":1280},{"value":2304},{"value":6140800728},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795828},"cpsr":{"value":1610616832},"fp":{"value":6140800608},"sp":{"value":6140800464},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27252,"symbol":"_pthread_cond_wait","symbolLocation":976,"imageIndex":71},{"imageOffset":458180,"symbol":"std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&)","symbolLocation":24,"imageIndex":68},{"imageOffset":606432,"symbol":"fml::ConcurrentMessageLoop::WorkerMain()","symbolLocation":140,"imageIndex":68},{"imageOffset":608136,"symbol":"void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*)","symbolLocation":192,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011022,"name":"io.worker.2","threadState":{"x":[{"value":4},{"value":0},{"value":1024},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6141373928},{"value":0},{"value":256},{"value":1099511628034},{"value":1099511628034},{"value":256},{"value":0},{"value":1099511628032},{"value":305},{"value":42},{"value":0},{"value":4425018216},{"value":4425018280},{"value":6141374688},{"value":0},{"value":0},{"value":1024},{"value":1024},{"value":1536},{"value":6141374168},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795828},"cpsr":{"value":1610616832},"fp":{"value":6141374048},"sp":{"value":6141373904},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27252,"symbol":"_pthread_cond_wait","symbolLocation":976,"imageIndex":71},{"imageOffset":458180,"symbol":"std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&)","symbolLocation":24,"imageIndex":68},{"imageOffset":606432,"symbol":"fml::ConcurrentMessageLoop::WorkerMain()","symbolLocation":140,"imageIndex":68},{"imageOffset":608136,"symbol":"void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*)","symbolLocation":192,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011023,"name":"io.worker.3","threadState":{"x":[{"value":4},{"value":0},{"value":1024},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6141947368},{"value":0},{"value":256},{"value":1099511628034},{"value":1099511628034},{"value":256},{"value":0},{"value":1099511628032},{"value":305},{"value":43},{"value":0},{"value":4425018216},{"value":4425018280},{"value":6141948128},{"value":0},{"value":0},{"value":1024},{"value":1024},{"value":1792},{"value":6141947608},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795828},"cpsr":{"value":1610616832},"fp":{"value":6141947488},"sp":{"value":6141947344},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27252,"symbol":"_pthread_cond_wait","symbolLocation":976,"imageIndex":71},{"imageOffset":458180,"symbol":"std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&)","symbolLocation":24,"imageIndex":68},{"imageOffset":606432,"symbol":"fml::ConcurrentMessageLoop::WorkerMain()","symbolLocation":140,"imageIndex":68},{"imageOffset":608136,"symbol":"void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*)","symbolLocation":192,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011024,"name":"io.worker.4","threadState":{"x":[{"value":260},{"value":0},{"value":1024},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6142520808},{"value":0},{"value":256},{"value":1099511628034},{"value":1099511628034},{"value":256},{"value":0},{"value":1099511628032},{"value":305},{"value":44},{"value":0},{"value":4425018216},{"value":4425018280},{"value":6142521568},{"value":0},{"value":0},{"value":1024},{"value":1024},{"value":2048},{"value":6142521048},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795828},"cpsr":{"value":1610616832},"fp":{"value":6142520928},"sp":{"value":6142520784},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27252,"symbol":"_pthread_cond_wait","symbolLocation":976,"imageIndex":71},{"imageOffset":458180,"symbol":"std::__fl::condition_variable::wait(std::__fl::unique_lock<std::__fl::mutex>&)","symbolLocation":24,"imageIndex":68},{"imageOffset":606432,"symbol":"fml::ConcurrentMessageLoop::WorkerMain()","symbolLocation":140,"imageIndex":68},{"imageOffset":608136,"symbol":"void* std::__fl::__thread_proxy[abi:nn210000]<std::__fl::tuple<std::__fl::unique_ptr<std::__fl::__thread_struct, std::__fl::default_delete<std::__fl::__thread_struct>>, fml::ConcurrentMessageLoop::ConcurrentMessageLoop(unsigned long)::$_0>>(void*)","symbolLocation":192,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011025,"name":"dart:io EventHandler","threadState":{"x":[{"value":4},{"value":0},{"value":0},{"value":6143618328},{"value":16},{"value":6143617288},{"value":314460325617408},{"value":0},{"value":184000000},{"value":4},{"value":62672162797824},{"value":62672162797826},{"value":256},{"value":1},{"value":73472},{"value":73216},{"value":363},{"value":105553156187976},{"value":0},{"value":105553156134624},{"value":6143617288},{"value":67108864},{"value":2147483647},{"value":274877907},{"value":4294966296},{"value":1000000},{"value":82709394},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4554056064},"cpsr":{"value":536875008},"fp":{"value":6143618928},"sp":{"value":6143617264},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380714588},"far":{"value":0}},"frames":[{"imageOffset":26204,"symbol":"kevent","symbolLocation":8,"imageIndex":70},{"imageOffset":5267840,"symbol":"dart::bin::EventHandlerImplementation::EventHandlerEntry(unsigned long)","symbolLocation":304,"imageIndex":68},{"imageOffset":5382744,"symbol":"dart::bin::ThreadStart(void*)","symbolLocation":92,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011026,"name":"Dart Profiler ThreadInterrupter","threadState":{"x":[{"value":260},{"value":0},{"value":1089024},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6144715288},{"value":0},{"value":2560},{"value":10995116280322},{"value":10995116280322},{"value":2560},{"value":0},{"value":10995116280320},{"value":305},{"value":105553162544352},{"value":0},{"value":105553162544256},{"value":105553162544328},{"value":6144717024},{"value":0},{"value":0},{"value":1089024},{"value":1089281},{"value":1089536},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795828},"cpsr":{"value":1610616832},"fp":{"value":6144715408},"sp":{"value":6144715264},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27252,"symbol":"_pthread_cond_wait","symbolLocation":976,"imageIndex":71},{"imageOffset":5700412,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":128,"imageIndex":68},{"imageOffset":7174800,"symbol":"dart::ThreadInterrupter::ThreadMain(unsigned long)","symbolLocation":336,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011027,"name":"Dart Profiler SampleBlockProcessor","threadState":{"x":[{"value":260},{"value":0},{"value":256},{"value":0},{"value":0},{"value":160},{"value":0},{"value":100000000},{"value":34561},{"value":0},{"value":0},{"value":2},{"value":2},{"value":0},{"value":0},{"value":0},{"value":305},{"value":105553162469120},{"value":0},{"value":105553162544384},{"value":105553162544456},{"value":1},{"value":100000000},{"value":0},{"value":256},{"value":34561},{"value":34816},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6145813136},"sp":{"value":6145812992},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":6876352,"symbol":"dart::SampleBlockProcessor::ThreadMain(unsigned long)","symbolLocation":220,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011093,"name":"DartWorker","threadState":{"x":[{"value":260},{"value":0},{"value":73472},{"value":0},{"value":0},{"value":160},{"value":61},{"value":0},{"value":73473},{"value":0},{"value":512},{"value":2199023256066},{"value":2199023256066},{"value":512},{"value":0},{"value":2199023256064},{"value":305},{"value":426},{"value":0},{"value":4426093976},{"value":105553156187952},{"value":1},{"value":0},{"value":61},{"value":73472},{"value":73473},{"value":73728},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":1000}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6149106160},"sp":{"value":6149106016},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":6093452,"symbol":"dart::MutatorThreadPool::OnEnterIdleLocked(dart::MutexLocker*, dart::ThreadPool::Worker*)","symbolLocation":156,"imageIndex":68},{"imageOffset":7177900,"symbol":"dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*)","symbolLocation":124,"imageIndex":68},{"imageOffset":7178640,"symbol":"dart::ThreadPool::Worker::Main(unsigned long)","symbolLocation":116,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011227,"name":"caulk.messenger.shared:17","threadState":{"x":[{"value":14},{"value":105553118639290},{"value":0},{"value":6150254698},{"value":105553118639264},{"value":25},{"value":0},{"value":0},{"value":0},{"value":4294967295},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":18446744073709551580},{"value":0},{"value":0},{"value":105553176055072},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":7425957040},"cpsr":{"value":2147487744},"fp":{"value":6150254464},"sp":{"value":6150254432},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691180},"far":{"value":0}},"frames":[{"imageOffset":2796,"symbol":"semaphore_wait_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":64688,"symbol":"caulk::semaphore::timed_wait(double)","symbolLocation":220,"imageIndex":82},{"imageOffset":96664,"symbol":"caulk::concurrent::details::worker_thread::run()","symbolLocation":28,"imageIndex":82},{"imageOffset":96780,"symbol":"void* caulk::thread_proxy<std::__1::tuple<caulk::thread::attributes, void (caulk::concurrent::details::worker_thread::*)(), std::__1::tuple<caulk::concurrent::details::worker_thread*>>>(void*)","symbolLocation":48,"imageIndex":82},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011239,"name":"caulk.messenger.shared:high","threadState":{"x":[{"value":14},{"value":105553118812348},{"value":0},{"value":6150828140},{"value":105553118812320},{"value":27},{"value":0},{"value":0},{"value":0},{"value":4294967295},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":18446744073709551580},{"value":0},{"value":0},{"value":105553176871776},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":7425957040},"cpsr":{"value":2147487744},"fp":{"value":6150827904},"sp":{"value":6150827872},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691180},"far":{"value":0}},"frames":[{"imageOffset":2796,"symbol":"semaphore_wait_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":64688,"symbol":"caulk::semaphore::timed_wait(double)","symbolLocation":220,"imageIndex":82},{"imageOffset":96664,"symbol":"caulk::concurrent::details::worker_thread::run()","symbolLocation":28,"imageIndex":82},{"imageOffset":96780,"symbol":"void* caulk::thread_proxy<std::__1::tuple<caulk::thread::attributes, void (caulk::concurrent::details::worker_thread::*)(), std::__1::tuple<caulk::concurrent::details::worker_thread*>>>(void*)","symbolLocation":48,"imageIndex":82},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011304,"frames":[],"threadState":{"x":[{"value":6151974912},{"value":66819},{"value":6151438336},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6151974912},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011384,"frames":[],"threadState":{"x":[{"value":6154268672},{"value":67623},{"value":6153732096},{"value":0},{"value":409603},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6154268672},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011385,"frames":[],"threadState":{"x":[{"value":6154842112},{"value":70691},{"value":6154305536},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6154842112},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011386,"frames":[],"threadState":{"x":[{"value":6155415552},{"value":83971},{"value":6154878976},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":4096},"fp":{"value":0},"sp":{"value":6155415552},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4383775108},"far":{"value":0}}},{"id":3011387,"name":"com.google.firebase.crashlytics.MachExceptionServer","threadState":{"x":[{"value":268451845},{"value":17179869190},{"value":0},{"value":0},{"value":0},{"value":359553187184640},{"value":92},{"value":0},{"value":0},{"value":17179869184},{"value":92},{"value":0},{"value":0},{"value":0},{"value":83715},{"value":92},{"value":18446744073709551569},{"value":0},{"value":0},{"value":0},{"value":92},{"value":359553187184640},{"value":0},{"value":0},{"value":4744560468},{"value":0},{"value":17179869190},{"value":18446744073709550527},{"value":6}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":4744560016},"sp":{"value":4744559936},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":145528,"sourceLine":196,"sourceFile":"FIRCLSMachException.c","symbol":"FIRCLSMachExceptionReadMessage","imageIndex":13,"symbolLocation":80},{"imageOffset":145328,"sourceLine":172,"sourceFile":"FIRCLSMachException.c","symbol":"FIRCLSMachExceptionServer","imageIndex":13,"symbolLocation":52},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011448,"name":"DartWorker","threadState":{"x":[{"value":260},{"value":0},{"value":128256},{"value":0},{"value":0},{"value":160},{"value":5},{"value":0},{"value":128257},{"value":0},{"value":1536},{"value":6597069768194},{"value":6597069768194},{"value":1536},{"value":0},{"value":6597069768192},{"value":305},{"value":73},{"value":0},{"value":4391485448},{"value":105553156317008},{"value":1},{"value":0},{"value":5},{"value":128256},{"value":128257},{"value":128512},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":1000}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6157625920},"sp":{"value":6157625776},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":7178288,"symbol":"dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*)","symbolLocation":512,"imageIndex":68},{"imageOffset":7178640,"symbol":"dart::ThreadPool::Worker::Main(unsigned long)","symbolLocation":116,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011449,"name":"DartWorker","threadState":{"x":[{"value":260},{"value":0},{"value":86784},{"value":0},{"value":0},{"value":160},{"value":5},{"value":0},{"value":86785},{"value":0},{"value":1792},{"value":7696581396226},{"value":7696581396226},{"value":1792},{"value":0},{"value":7696581396224},{"value":305},{"value":479},{"value":0},{"value":4391485448},{"value":105553156317680},{"value":1},{"value":0},{"value":5},{"value":86784},{"value":86785},{"value":87040},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":1000}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6158723648},"sp":{"value":6158723504},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":7178288,"symbol":"dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*)","symbolLocation":512,"imageIndex":68},{"imageOffset":7178640,"symbol":"dart::ThreadPool::Worker::Main(unsigned long)","symbolLocation":116,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011538,"name":"com.apple.NSURLConnectionLoader","threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592},{"value":324437534572544},{"value":0},{"value":324437534572544},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":75539},{"value":3072},{"value":18446744073709551569},{"value":2199023256066},{"value":0},{"value":4294967295},{"value":2},{"value":324437534572544},{"value":0},{"value":324437534572544},{"value":6159293768},{"value":8589934592},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4380760332},"cpsr":{"value":4096},"fp":{"value":6159293616},"sp":{"value":6159293536},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380691312},"far":{"value":0}},"frames":[{"imageOffset":2928,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":70},{"imageOffset":71948,"symbol":"mach_msg2_internal","symbolLocation":72,"imageIndex":70},{"imageOffset":35856,"symbol":"mach_msg_overwrite","symbolLocation":480,"imageIndex":70},{"imageOffset":3812,"symbol":"mach_msg","symbolLocation":20,"imageIndex":70},{"imageOffset":601092,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":156,"imageIndex":76},{"imageOffset":597436,"symbol":"__CFRunLoopRun","symbolLocation":1128,"imageIndex":76},{"imageOffset":576748,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":496,"imageIndex":76},{"imageOffset":2100588,"symbol":"+[__CFN_CoreSchedulingSetRunnable _run:]","symbolLocation":368,"imageIndex":83},{"imageOffset":9256212,"symbol":"__NSThread__start__","symbolLocation":716,"imageIndex":81},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011990,"name":"DartWorker","threadState":{"x":[{"value":260},{"value":0},{"value":10240},{"value":0},{"value":0},{"value":160},{"value":4},{"value":992506000},{"value":10241},{"value":0},{"value":1792},{"value":7696581396226},{"value":7696581396226},{"value":1792},{"value":0},{"value":7696581396224},{"value":305},{"value":86},{"value":0},{"value":4391485448},{"value":105553156491088},{"value":1},{"value":992506000},{"value":4},{"value":10240},{"value":10241},{"value":10496},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":1000}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6132017728},"sp":{"value":6132017584},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":7178288,"symbol":"dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*)","symbolLocation":512,"imageIndex":68},{"imageOffset":7178640,"symbol":"dart::ThreadPool::Worker::Main(unsigned long)","symbolLocation":116,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]},{"id":3011991,"name":"DartWorker","threadState":{"x":[{"value":260},{"value":0},{"value":256},{"value":0},{"value":0},{"value":160},{"value":4},{"value":999782000},{"value":257},{"value":0},{"value":1536},{"value":6597069768194},{"value":6597069768194},{"value":1536},{"value":0},{"value":6597069768192},{"value":305},{"value":3529156659},{"value":0},{"value":4391485448},{"value":105553156463024},{"value":1},{"value":999782000},{"value":4},{"value":256},{"value":257},{"value":512},{"value":4581617664,"symbolLocation":5352,"symbol":"dart::Symbols::symbol_handles_"},{"value":1000}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4383795872},"cpsr":{"value":2684358656},"fp":{"value":6153071168},"sp":{"value":6153071024},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":4380704800},"far":{"value":0}},"frames":[{"imageOffset":16416,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":70},{"imageOffset":27296,"symbol":"_pthread_cond_wait","symbolLocation":1020,"imageIndex":71},{"imageOffset":5700396,"symbol":"dart::ConditionVariable::WaitMicros(dart::Mutex*, long long)","symbolLocation":112,"imageIndex":68},{"imageOffset":7178288,"symbol":"dart::ThreadPool::WorkerLoop(dart::ThreadPool::Worker*)","symbolLocation":512,"imageIndex":68},{"imageOffset":7178640,"symbol":"dart::ThreadPool::Worker::Main(unsigned long)","symbolLocation":116,"imageIndex":68},{"imageOffset":6855872,"symbol":"dart::ThreadStart(void*)","symbolLocation":208,"imageIndex":68},{"imageOffset":26028,"symbol":"_pthread_start","symbolLocation":104,"imageIndex":71},{"imageOffset":6552,"symbol":"thread_start","symbolLocation":8,"imageIndex":71}]}],
  "usedImages" : [
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 4338057216,
    "size" : 655360,
    "uuid" : "bc4db5f4-1c64-3706-8006-73b78c3e1f1a",
    "path" : "\/usr\/lib\/dyld",
    "name" : "dyld"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4336517120,
    "CFBundleShortVersionString" : "1.0.1",
    "CFBundleIdentifier" : "com.bd.bdnewsreader",
    "size" : 16384,
    "uuid" : "7c18d5b1-7beb-36ef-90a5-7d5383b356f4",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Runner",
    "name" : "Runner",
    "CFBundleVersion" : "24"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355850240,
    "size" : 12582912,
    "uuid" : "583cd91b-b5c1-327f-a127-283cad12f20b",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Runner.debug.dylib",
    "name" : "Runner.debug.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4339318784,
    "CFBundleShortVersionString" : "1.7.6",
    "CFBundleIdentifier" : "org.cocoapods.AppAuth",
    "size" : 163840,
    "uuid" : "3d931d83-3ab5-3ba5-bd0d-fc911479ce24",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/AppAuth.framework\/AppAuth",
    "name" : "AppAuth",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4339679232,
    "CFBundleShortVersionString" : "11.2.0",
    "CFBundleIdentifier" : "org.cocoapods.AppCheckCore",
    "size" : 147456,
    "uuid" : "f8ab13d8-ccfe-3ca8-b5b2-a85d2a107ee4",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/AppCheckCore.framework\/AppCheckCore",
    "name" : "AppCheckCore",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4336844800,
    "CFBundleShortVersionString" : "2.4.0",
    "CFBundleIdentifier" : "org.cocoapods.FBLPromises",
    "size" : 81920,
    "uuid" : "5b1da8bb-942e-3b5f-b535-85086af24c39",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FBLPromises.framework\/FBLPromises",
    "name" : "FBLPromises",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4337057792,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseABTesting",
    "size" : 49152,
    "uuid" : "b0e558cf-79e0-308a-b3ed-fdfa5b9f2a88",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseABTesting.framework\/FirebaseABTesting",
    "name" : "FirebaseABTesting",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4336713728,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseAppCheckInterop",
    "size" : 16384,
    "uuid" : "fffbd269-8ac1-39ec-8ac7-f3bd601f7206",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseAppCheckInterop.framework\/FirebaseAppCheckInterop",
    "name" : "FirebaseAppCheckInterop",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4343922688,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseAuth",
    "size" : 1622016,
    "uuid" : "d1af881a-fce8-39b9-8352-95c4fdd62cb5",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseAuth.framework\/FirebaseAuth",
    "name" : "FirebaseAuth",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340039680,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseAuthInterop",
    "size" : 16384,
    "uuid" : "10ffbc20-53a0-3bae-b189-4531516bdabf",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseAuthInterop.framework\/FirebaseAuthInterop",
    "name" : "FirebaseAuthInterop",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340350976,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseCore",
    "size" : 81920,
    "uuid" : "3b8908ae-3e54-3c63-8d75-ac4dab148575",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseCore.framework\/FirebaseCore",
    "name" : "FirebaseCore",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340121600,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseCoreExtension",
    "size" : 16384,
    "uuid" : "34987ade-f561-3891-9790-9dfe36ec206c",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseCoreExtension.framework\/FirebaseCoreExtension",
    "name" : "FirebaseCoreExtension",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341071872,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseCoreInternal",
    "size" : 163840,
    "uuid" : "51f0025f-890a-3c40-bfe7-8f95ffa086da",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseCoreInternal.framework\/FirebaseCoreInternal",
    "name" : "FirebaseCoreInternal",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4342579200,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseCrashlytics",
    "size" : 458752,
    "uuid" : "0d335795-a4d7-3564-8df8-401e42e9c951",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseCrashlytics.framework\/FirebaseCrashlytics",
    "name" : "FirebaseCrashlytics",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4349116416,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseFirestore",
    "size" : 425984,
    "uuid" : "9b4ee40f-7762-32b5-83d8-4f12dd732c79",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseFirestore.framework\/FirebaseFirestore",
    "name" : "FirebaseFirestore",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4393713664,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseFirestoreInternal",
    "size" : 5799936,
    "uuid" : "122cbd3f-7c6f-3bab-b52c-3dde06fd6efd",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseFirestoreInternal.framework\/FirebaseFirestoreInternal",
    "name" : "FirebaseFirestoreInternal",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341563392,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseInstallations",
    "size" : 114688,
    "uuid" : "2f398c4b-b451-3bc7-89ee-8ba10778fc7c",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseInstallations.framework\/FirebaseInstallations",
    "name" : "FirebaseInstallations",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4347805696,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseMessaging",
    "size" : 278528,
    "uuid" : "a55b0624-fd08-3d7c-8717-f52bb628de71",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseMessaging.framework\/FirebaseMessaging",
    "name" : "FirebaseMessaging",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4348379136,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebasePerformance",
    "size" : 278528,
    "uuid" : "6015943b-721a-3b19-8925-3983996cb0ac",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebasePerformance.framework\/FirebasePerformance",
    "name" : "FirebasePerformance",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4350410752,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseRemoteConfig",
    "size" : 262144,
    "uuid" : "6cfe5162-dfd9-3da1-a65d-c86afd0f4cf9",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseRemoteConfig.framework\/FirebaseRemoteConfig",
    "name" : "FirebaseRemoteConfig",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340563968,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseRemoteConfigInterop",
    "size" : 32768,
    "uuid" : "580a486d-2fec-36fc-bda7-9f459e595334",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseRemoteConfigInterop.framework\/FirebaseRemoteConfigInterop",
    "name" : "FirebaseRemoteConfigInterop",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4350984192,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseSessions",
    "size" : 180224,
    "uuid" : "b138badb-584f-354d-9ee4-1287e87e4397",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseSessions.framework\/FirebaseSessions",
    "name" : "FirebaseSessions",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4351541248,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseSharedSwift",
    "size" : 311296,
    "uuid" : "7b2c20ab-3cfe-3064-9437-7b9a015f31bb",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseSharedSwift.framework\/FirebaseSharedSwift",
    "name" : "FirebaseSharedSwift",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4353130496,
    "CFBundleShortVersionString" : "12.8.0",
    "CFBundleIdentifier" : "org.cocoapods.FirebaseStorage",
    "size" : 360448,
    "uuid" : "d79b18f8-16ac-35b9-b1af-abd6453ce8df",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/FirebaseStorage.framework\/FirebaseStorage",
    "name" : "FirebaseStorage",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340695040,
    "CFBundleShortVersionString" : "4.1.1",
    "CFBundleIdentifier" : "org.cocoapods.GTMAppAuth",
    "size" : 147456,
    "uuid" : "925a13bb-e68d-3012-af08-8a1b3093b09a",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/GTMAppAuth.framework\/GTMAppAuth",
    "name" : "GTMAppAuth",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4352262144,
    "CFBundleShortVersionString" : "3.5.0",
    "CFBundleIdentifier" : "org.cocoapods.GTMSessionFetcher",
    "size" : 344064,
    "uuid" : "a8280994-1893-3278-881c-85ff838dc9f2",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/GTMSessionFetcher.framework\/GTMSessionFetcher",
    "name" : "GTMSessionFetcher",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4353982464,
    "CFBundleShortVersionString" : "10.1.0",
    "CFBundleIdentifier" : "org.cocoapods.GoogleDataTransport",
    "size" : 196608,
    "uuid" : "7599b43d-5f07-33d1-9b42-20bf11de5c70",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/GoogleDataTransport.framework\/GoogleDataTransport",
    "name" : "GoogleDataTransport",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4342185984,
    "CFBundleShortVersionString" : "8.0.0",
    "CFBundleIdentifier" : "org.cocoapods.GoogleSignIn",
    "size" : 147456,
    "uuid" : "e4dc0a8b-7541-3291-acf2-d59a68e63de3",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/GoogleSignIn.framework\/GoogleSignIn",
    "name" : "GoogleSignIn",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4343578624,
    "CFBundleShortVersionString" : "8.1.0",
    "CFBundleIdentifier" : "org.cocoapods.GoogleUtilities",
    "size" : 147456,
    "uuid" : "339e3061-c702-3d18-9a04-c80a415f39a6",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/GoogleUtilities.framework\/GoogleUtilities",
    "name" : "GoogleUtilities",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4352884736,
    "CFBundleShortVersionString" : "6.0.3",
    "CFBundleIdentifier" : "org.cocoapods.OrderedSet",
    "size" : 49152,
    "uuid" : "a06b1866-6fe9-3382-85a5-85a38fa26942",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/OrderedSet.framework\/OrderedSet",
    "name" : "OrderedSet",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4354408448,
    "CFBundleShortVersionString" : "2.4.0",
    "CFBundleIdentifier" : "org.cocoapods.Promises",
    "size" : 98304,
    "uuid" : "e78ef7da-bc68-3776-81ad-10ac20d54f2f",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/Promises.framework\/Promises",
    "name" : "Promises",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340203520,
    "CFBundleShortVersionString" : "101.0.0",
    "CFBundleIdentifier" : "org.cocoapods.RecaptchaInterop",
    "size" : 16384,
    "uuid" : "33be8149-4570-30ea-b90b-113f330fff47",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/RecaptchaInterop.framework\/RecaptchaInterop",
    "name" : "RecaptchaInterop",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4376346624,
    "CFBundleShortVersionString" : "1.20240722.0",
    "CFBundleIdentifier" : "org.cocoapods.absl",
    "size" : 1490944,
    "uuid" : "2d9b9e7d-4622-35ac-a5b4-c070a0b485a4",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/absl.framework\/absl",
    "name" : "absl",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341972992,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.audio-service",
    "size" : 32768,
    "uuid" : "0a39789d-d762-392b-b31b-854e14942435",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/audio_service.framework\/audio_service",
    "name" : "audio_service",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4354850816,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.audio-session",
    "size" : 65536,
    "uuid" : "f32be535-2609-394d-a92c-fbba219a0f0f",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/audio_session.framework\/audio_session",
    "name" : "audio_session",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355391488,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.audioplayers-darwin",
    "size" : 131072,
    "uuid" : "8e771bb3-3f93-30e0-9db4-e9b829ddb28c",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/audioplayers_darwin.framework\/audioplayers_darwin",
    "name" : "audioplayers_darwin",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4354670592,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.connectivity-plus",
    "size" : 49152,
    "uuid" : "21cbf6ac-62fd-38a3-9bc7-d5cf76dbfe43",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/connectivity_plus.framework\/connectivity_plus",
    "name" : "connectivity_plus",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4336615424,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.device-info-plus",
    "size" : 32768,
    "uuid" : "b9c06550-4da0-3cae-887e-67943acf0cab",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/device_info_plus.framework\/device_info_plus",
    "name" : "device_info_plus",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341841920,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.flutter-haptic-feedback",
    "size" : 32768,
    "uuid" : "e13ddc03-50f8-3c7a-b849-a29af1d0617e",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/flutter_haptic_feedback.framework\/flutter_haptic_feedback",
    "name" : "flutter_haptic_feedback",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4384063488,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.flutter-inappwebview-ios",
    "size" : 1802240,
    "uuid" : "4fabfd5d-6774-3c55-83af-bc2921ede8d9",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/flutter_inappwebview_ios.framework\/flutter_inappwebview_ios",
    "name" : "flutter_inappwebview_ios",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355194880,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.flutter-local-notifications",
    "size" : 65536,
    "uuid" : "ea7bae8f-e044-3a34-a78d-8794253ea3bd",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/flutter_local_notifications.framework\/flutter_local_notifications",
    "name" : "flutter_local_notifications",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4348985344,
    "CFBundleShortVersionString" : "2.4.3",
    "CFBundleIdentifier" : "org.cocoapods.flutter-native-splash",
    "size" : 16384,
    "uuid" : "2775540b-db2c-392d-889a-0c8e39851553",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/flutter_native_splash.framework\/flutter_native_splash",
    "name" : "flutter_native_splash",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4372807680,
    "CFBundleShortVersionString" : "10.0.0",
    "CFBundleIdentifier" : "org.cocoapods.flutter-secure-storage-darwin",
    "size" : 98304,
    "uuid" : "d1793e9f-4f2d-3319-996a-23cb4949acd7",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/flutter_secure_storage_darwin.framework\/flutter_secure_storage_darwin",
    "name" : "flutter_secure_storage_darwin",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4372512768,
    "CFBundleShortVersionString" : "0.0.2",
    "CFBundleIdentifier" : "org.cocoapods.fluttertoast",
    "size" : 49152,
    "uuid" : "bd64a034-ef25-3244-91e1-a7b04d606ea5",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/fluttertoast.framework\/fluttertoast",
    "name" : "fluttertoast",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4342087680,
    "CFBundleShortVersionString" : "1.0.5",
    "CFBundleIdentifier" : "org.cocoapods.geocoding-ios",
    "size" : 32768,
    "uuid" : "f386ba3f-fd1f-3413-9033-94924b4e4e99",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/geocoding_ios.framework\/geocoding_ios",
    "name" : "geocoding_ios",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4372660224,
    "CFBundleShortVersionString" : "1.2.0",
    "CFBundleIdentifier" : "org.cocoapods.geolocator-apple",
    "size" : 49152,
    "uuid" : "32a92996-006f-318b-9c0a-a572b8f9c00f",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/geolocator_apple.framework\/geolocator_apple",
    "name" : "geolocator_apple",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4461461504,
    "CFBundleShortVersionString" : "1.69.0",
    "CFBundleIdentifier" : "org.cocoapods.grpc",
    "size" : 13221888,
    "uuid" : "528c4828-1e4a-3f92-846a-5a05a836a2d5",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/grpc.framework\/grpc",
    "name" : "grpc",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4387962880,
    "CFBundleShortVersionString" : "1.69.0",
    "CFBundleIdentifier" : "org.cocoapods.grpcpp",
    "size" : 835584,
    "uuid" : "047ad4fb-e048-332a-b748-63a1d94879e7",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/grpcpp.framework\/grpcpp",
    "name" : "grpcpp",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373331968,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.image-picker-ios",
    "size" : 98304,
    "uuid" : "2e2eb92e-189e-3d73-b34e-97853205d201",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/image_picker_ios.framework\/image_picker_ios",
    "name" : "image_picker_ios",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4374511616,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.in-app-purchase-storekit",
    "size" : 393216,
    "uuid" : "052e20cf-189d-3134-a464-7efb8f770bcc",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/in_app_purchase_storekit.framework\/in_app_purchase_storekit",
    "name" : "in_app_purchase_storekit",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373086208,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.integration-test",
    "size" : 32768,
    "uuid" : "d9160f91-1b58-3dd6-b31e-5353c4031167",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/integration_test.framework\/integration_test",
    "name" : "integration_test",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373790720,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.just-audio",
    "size" : 98304,
    "uuid" : "60fccbec-7331-3241-b68a-24ae0936fca1",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/just_audio.framework\/just_audio",
    "name" : "just_audio",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4381310976,
    "CFBundleShortVersionString" : "1.22.6",
    "CFBundleIdentifier" : "org.cocoapods.leveldb",
    "size" : 425984,
    "uuid" : "531e15c9-3d38-3006-b987-b3fae6b25bc6",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/leveldb.framework\/leveldb",
    "name" : "leveldb",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4375445504,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.local-auth-darwin",
    "size" : 98304,
    "uuid" : "a38ca77e-9a0a-31fb-96d2-6288ad877660",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/local_auth_darwin.framework\/local_auth_darwin",
    "name" : "local_auth_darwin",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355751936,
    "CFBundleShortVersionString" : "3.30910.0",
    "CFBundleIdentifier" : "org.cocoapods.nanopb",
    "size" : 32768,
    "uuid" : "e4ea8e47-8890-3897-ac86-b5cfbd2064f3",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/nanopb.framework\/nanopb",
    "name" : "nanopb",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4418174976,
    "CFBundleShortVersionString" : "0.0.37",
    "CFBundleIdentifier" : "org.cocoapods.openssl-grpc",
    "size" : 1867776,
    "uuid" : "650a7f0b-fbcb-3db7-8571-f9616bcf614e",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/openssl_grpc.framework\/openssl_grpc",
    "name" : "openssl_grpc",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355112960,
    "CFBundleShortVersionString" : "0.4.5",
    "CFBundleIdentifier" : "org.cocoapods.package-info-plus",
    "size" : 16384,
    "uuid" : "f6a68753-25ae-3ef6-beea-593905c03ab4",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/package_info_plus.framework\/package_info_plus",
    "name" : "package_info_plus",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4373200896,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.path-provider-foundation",
    "size" : 32768,
    "uuid" : "ea8c98e7-1781-39f7-a113-bdf2e9fbad0b",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/path_provider_foundation.framework\/path_provider_foundation",
    "name" : "path_provider_foundation",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4374003712,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.share-plus",
    "size" : 32768,
    "uuid" : "0ce48ef1-347c-3035-a8be-d4a43856f68f",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/share_plus.framework\/share_plus",
    "name" : "share_plus",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4375724032,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.shared-preferences-foundation",
    "size" : 81920,
    "uuid" : "ebc70aab-d774-3a4b-baa1-4d22df5a04a1",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/shared_preferences_foundation.framework\/shared_preferences_foundation",
    "name" : "shared_preferences_foundation",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4375969792,
    "CFBundleShortVersionString" : "0.0.4",
    "CFBundleIdentifier" : "org.cocoapods.sqflite-darwin",
    "size" : 131072,
    "uuid" : "657ec0a3-2a7b-32ee-a7ea-b41e7569f287",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/sqflite_darwin.framework\/sqflite_darwin",
    "name" : "sqflite_darwin",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4414898176,
    "CFBundleShortVersionString" : "3.51.1",
    "CFBundleIdentifier" : "org.cocoapods.sqlite3",
    "size" : 1409024,
    "uuid" : "3857bfbd-444d-3a0d-9e82-5a77177f6b63",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/sqlite3.framework\/sqlite3",
    "name" : "sqlite3",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355014656,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.sqlite3-flutter-libs",
    "size" : 16384,
    "uuid" : "75f4e2af-8243-349a-9ae3-3378dd0a3dbb",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/sqlite3_flutter_libs.framework\/sqlite3_flutter_libs",
    "name" : "sqlite3_flutter_libs",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4380164096,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.url-launcher-ios",
    "size" : 81920,
    "uuid" : "baebcffb-9f43-3d3f-80ad-388d04f6249b",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/url_launcher_ios.framework\/url_launcher_ios",
    "name" : "url_launcher_ios",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4380409856,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.video-player-avfoundation",
    "size" : 114688,
    "uuid" : "26c532e2-e0e0-3fb2-a917-b2f08822c8c6",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/video_player_avfoundation.framework\/video_player_avfoundation",
    "name" : "video_player_avfoundation",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4374118400,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.wakelock-plus",
    "size" : 32768,
    "uuid" : "b309161c-f9b0-3bcc-8a70-cce0a7be860d",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/wakelock_plus.framework\/wakelock_plus",
    "name" : "wakelock_plus",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4421468160,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.webview-flutter-wkwebview",
    "size" : 704512,
    "uuid" : "e2d3fd42-8f40-3a3c-9ea9-2dbcf4bc8417",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/webview_flutter_wkwebview.framework\/webview_flutter_wkwebview",
    "name" : "webview_flutter_wkwebview",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4383113216,
    "CFBundleShortVersionString" : "0.0.1",
    "CFBundleIdentifier" : "org.cocoapods.workmanager-apple",
    "size" : 262144,
    "uuid" : "bd3bc9dc-7905-3546-9e3b-f34220b8d842",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/workmanager_apple.framework\/workmanager_apple",
    "name" : "workmanager_apple",
    "CFBundleVersion" : "1"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4548788224,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "io.flutter.flutter",
    "size" : 32014336,
    "uuid" : "4c4c4472-5555-3144-a129-5b766c61c004",
    "path" : "\/Users\/USER\/Library\/Developer\/CoreSimulator\/Devices\/84AEE392-9A81-4F9C-A10F-2732ED430B5C\/data\/Containers\/Bundle\/Application\/6D9F0007-7E46-4A60-95AB-3891BC2AEE67\/Runner.app\/Frameworks\/Flutter.framework\/Flutter",
    "name" : "Flutter",
    "CFBundleVersion" : "1.0"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4374233088,
    "size" : 32768,
    "uuid" : "9463fc06-cc7c-38e8-ad3c-1b9f2617df53",
    "path" : "\/usr\/lib\/system\/libsystem_platform.dylib",
    "name" : "libsystem_platform.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4380688384,
    "size" : 245760,
    "uuid" : "1a15cc38-efcc-34ea-a261-cfd370f4b557",
    "path" : "\/usr\/lib\/system\/libsystem_kernel.dylib",
    "name" : "libsystem_kernel.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4383768576,
    "size" : 65536,
    "uuid" : "b1095734-2a4d-3e8c-839e-b10ae9598d61",
    "path" : "\/usr\/lib\/system\/libsystem_pthread.dylib",
    "name" : "libsystem_pthread.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4391337984,
    "size" : 49152,
    "uuid" : "997b234d-5c24-3e21-97d6-33b6853818c0",
    "path" : "\/Volumes\/VOLUME\/*\/libobjc-trampolines.dylib",
    "name" : "libobjc-trampolines.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6443765760,
    "size" : 512708,
    "uuid" : "e0197e7b-9d61-356a-90b7-4be1270b82d5",
    "path" : "\/Volumes\/VOLUME\/*\/libsystem_c.dylib",
    "name" : "libsystem_c.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6445539328,
    "size" : 99696,
    "uuid" : "0fc14bd2-2110-348c-8278-7a6fb63a7000",
    "path" : "\/Volumes\/VOLUME\/*\/libc++abi.dylib",
    "name" : "libc++abi.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6442909696,
    "size" : 250520,
    "uuid" : "880f8664-cd53-3912-bdd5-5e3159295f7d",
    "path" : "\/Volumes\/VOLUME\/*\/libobjc.A.dylib",
    "name" : "libobjc.A.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6446395392,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.CoreFoundation",
    "size" : 4309888,
    "uuid" : "4f6d050d-95ee-3a95-969c-3a98b29df6ff",
    "path" : "\/Volumes\/VOLUME\/*\/CoreFoundation.framework\/CoreFoundation",
    "name" : "CoreFoundation",
    "CFBundleVersion" : "4201"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6444281856,
    "size" : 283072,
    "uuid" : "ec9ecf10-959d-3da1-a055-6de970159b9d",
    "path" : "\/Volumes\/VOLUME\/*\/libdispatch.dylib",
    "name" : "libdispatch.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6755336192,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.GraphicsServices",
    "size" : 32192,
    "uuid" : "4e5b0462-6170-3367-9475-4ff8b8dfe4e6",
    "path" : "\/Volumes\/VOLUME\/*\/GraphicsServices.framework\/GraphicsServices",
    "name" : "GraphicsServices",
    "CFBundleVersion" : "1.0"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6528032768,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.UIKitCore",
    "size" : 35792672,
    "uuid" : "196154ff-ba04-33cd-9277-98f9aa0b7499",
    "path" : "\/Volumes\/VOLUME\/*\/UIKitCore.framework\/UIKitCore",
    "name" : "UIKitCore",
    "CFBundleVersion" : "9126.2.4.1.111"
  },
  {
    "size" : 0,
    "source" : "A",
    "base" : 0,
    "uuid" : "00000000-0000-0000-0000-000000000000"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6451228672,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.Foundation",
    "size" : 14100704,
    "uuid" : "c153116f-dd31-3fa9-89bb-04b47c1fa83d",
    "path" : "\/Volumes\/VOLUME\/*\/Foundation.framework\/Foundation",
    "name" : "Foundation",
    "CFBundleVersion" : "4201"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 7425892352,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.audio.caulk",
    "size" : 157120,
    "uuid" : "3e592a6d-e4ae-387e-9f93-b81c874443dc",
    "path" : "\/Volumes\/VOLUME\/*\/caulk.framework\/caulk",
    "name" : "caulk"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 6522978304,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.CFNetwork",
    "size" : 3613024,
    "uuid" : "1bb7d015-7687-34a6-93c8-7cc24655033a",
    "path" : "\/Volumes\/VOLUME\/*\/CFNetwork.framework\/CFNetwork",
    "name" : "CFNetwork",
    "CFBundleVersion" : "3860.300.31"
  }
],
  "sharedCache" : {
  "base" : 6442450944,
  "size" : 4230184960,
  "uuid" : "a6bd90dd-ce8e-328b-a043-9a2e33e638ca"
},
  "vmSummary" : "ReadOnly portion of Libraries: Total=2.1G resident=0K(0%) swapped_out_or_unallocated=2.1G(100%)\nWritable regions: Total=969.0M written=2291K(0%) resident=2243K(0%) swapped_out=48K(0%) unallocated=966.7M(100%)\n\n                                VIRTUAL   REGION \nREGION TYPE                        SIZE    COUNT (non-coalesced) \n===========                     =======  ======= \nActivity Tracing                   256K        1 \nFoundation                          16K        1 \nIOSurface                         44.7M        5 \nKernel Alloc Once                   32K        1 \nMALLOC                           653.8M      129 \nMALLOC guard page                  128K        8 \nMach message                        16K        1 \nSQLite page cache                 1664K       13 \nSTACK GUARD                       56.4M       27 \nStack                             30.4M       31 \nVM_ALLOCATE                      251.2M      815 \n__DATA                            63.1M     1107 \n__DATA_CONST                     133.0M     1128 \n__DATA_DIRTY                       139K       13 \n__FONT_DATA                        2352        1 \n__LINKEDIT                       780.4M       74 \n__OBJC_RO                         62.5M        1 \n__OBJC_RW                         2771K        1 \n__TEXT                             1.3G     1143 \n__TPRO_CONST                       148K        2 \ndyld private memory                2.2G       20 \nmapped file                      200.1M       37 \npage table in kernel              2243K        1 \nshared memory                       16K        1 \n===========                     =======  ======= \nTOTAL                              5.7G     4561 \n",
  "legacyInfo" : {
  "threadTriggered" : {
    "queue" : "com.apple.main-thread"
  }
},
  "logWritingSignature" : "f01fc370eff566ce42f259bdb8ee31893595befe",
  "bug_type" : "309",
  "roots_installed" : 0,
  "trmStatus" : 1,
  "trialInfo" : {
  "rollouts" : [
    {
      "rolloutId" : "6410af69ed1e1e7ab93ed169",
      "factorPackIds" : [

      ],
      "deploymentId" : 240000011
    },
    {
      "rolloutId" : "5f72dc58705eff005a46b3a9",
      "factorPackIds" : [

      ],
      "deploymentId" : 240000015
    }
  ],
  "experiments" : [

  ]
}
}

Model: Mac15,6, BootROM 13822.81.10, proc 11:5:6 processors, 18 GB, SMC 
Graphics: Apple M3 Pro, Apple M3 Pro, Built-In
Display: Color LCD, 3024 x 1964 Retina, Main, MirrorOff, Online
Memory Module: LPDDR5, Micron
AirPort: spairport_wireless_card_type_wifi (0x14E4, 0x4388), wl0: Dec  6 2025 00:29:46 version 23.41.8.0.41.51.201 FWID 01-84de0866
IO80211_driverkit-1540.16 "IO80211_driverkit-1540.16" Jan 27 2026 21:04:24
AirPort: 
Bluetooth: Version (null), 0 services, 0 devices, 0 incoming serial ports
Network Service: Wi-Fi, AirPort, en0
Thunderbolt Bus: MacBook Pro, Apple Inc.
Thunderbolt Bus: MacBook Pro, Apple Inc.
Thunderbolt Bus: MacBook Pro, Apple Inc.

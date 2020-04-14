# Checkpointing with Qemu

Create a disk and run Alpine:

```
$ ./run.sh
```

Get whatever bytes you need on there to run an app. E.g. `apk add openjdk8-jre` and run `java -jar ...`. You can make a snapshot of the VM from the monitor (it will increase the size of the file on disk by the size of the memory you asked for on the command line):

```
(qemu) savevm server
(qemu) quit
```

and then, back in the host, once you have quit you can list the snapshots:

```
$ qemu-img snapshot -l disk.qcow
Snapshot list:
ID        TAG                 VM SIZE                DATE       VM CLOCK
1         server                  134M 2020-02-24 16:25:13   00:01:41.358
```

You can restart really fast:

```
$ ./run.sh
```

## Results

With `-m 1024` things are pretty slow to start from cold, but much faster when warm (from a snapshot). Making more memory available helps, and so does using KVM (`-enable-kvm`):

| App type        | KVM | Memory | Cold start | Warm start |
| --------------- | --- | ------ | ---------- | ---------- |
| Petclinic       | N   | 1G     | 200s       | 1.086s     |
| Webflux         | N   | 1G     | 30s        | 0.478s     |
| Webflux         | Y   | 512M   | 4s         | 0.378s     |
| Webflux(tiny)   | Y   | 512M   | 2s         | 0.200s     |
| Webflux(tiny)   | Y   | 256M   | 2s         | 0.210s     |
| Petclinic       | N   | 4G     | 80s        | 0.757s     |
| Petclinic(tiny) | Y   | 512M   | 7s         | 0.316s     |
| Petclinic       | Y   | 512M   | 13s        | 0.455s     |
| Petclinic       | Y   | 1G     | 18s        | 0.405s     |
| Petclinic       | Y   | 4G     | 12s        | 0.525s     |

The warm start time is "time to first request" using `./ttfr.sh`. The cold starts are as reported by Spring Boot, so do not include the first request or the VM boot time. The "Webflux" sample would have started in 850ms from cold on the host, and "Petclinic" would have been 4s. Not being sure what the default CPU constraints are, I tried with explicit `-smp n` values (`n=1,2,4`) - cold and warm starts all got slower so the default is probably "use all". There seems to be a limit to how fast a warm start will go with the regular alpine image (roughly 400ms minimum) - maybe to do with the size of the JVM process? The "tiny" results above are for a [Tiny Core](http://tinycorelinux.net) image which can start with less memory. The "tiny" Petclinic had to remove Actuators and caches, and also upgrade a webjars dependency so that it would work with the limited JVM available on Tiny Core.

## Qemu Tips

-   There is an awesome script you can use to create an image from the command line: https://github.com/alpinelinux/alpine-make-vm-image. My fork configures the VM to expose SSH and install the JVM: https://github.com/dsyer/alpine-make-vm-image and provides a convenient `run.sh` script to initialize and start the VM.
-   You can run `qemu-system*` without a GUI using `-nographic` on the command line. Then `Ctrl-A C` opens and toggles the monitor, and `Ctrl-A X` quits.
-   Another "headless" option is `-curses` which displays the guest terminal console in your command line window using `libcurses`. Press `Esc-2` to get the monitor and `Esc-1` to go back again. I had issues with special characters (like `|` and \`) in the terminal.
-   As well as the `-net` command line option, you can add `-redir tcp:8080::8080:` to expose a specific port on the host (N.B. this flag is deprecated).
-   Openssh is installed in the VM if you ask for it, but it won't allow password logins for root by default. You have to edit `/etc/ssh/sshd_config` and set `PermitRootLogin yes` to make it work (then `service sshd restart`).

## Manual VM Image Preparation

```
$ qemu-img create -f qcow2 disk.qcow 2G
```

Install Alpine Linux (login as root with no password and follow the instructions in the UI, install into `sda` with `sys` layout):

```
$ qemu-system-x86_64 -hda disk.qcow -cdrom alpine-standard-3.11.3-x86_64.iso -boot d -net nic -net user -localtime -m 1024
```

The disk file should be under 40MB at this point. Quit the VM and re-boot it to start up in the new hard disk system. At any time you want you can go into the qemu monitor with `Alt-Ctrl-2`. Type `quit` to exit the VM.

In a vanilla Alpine you can install docker by uncommenting the "community" repository in `/etc/apk/repositories` and then running `apk add docker`.

-   To start the Docker daemon at boot, run `rc-update add docker boot`.
-   To start the Docker daemon manually, run `service docker start`.

The disk file has grown to 700MB or maybe more.

Run an app in the VM, e.g.

```
$ docker run -p 8080:8080 dsyer/demo

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.2.4.RELEASE)

2020-02-24 10:45:33.181  INFO 1 --- [           main] com.example.ServerApplication            : Starting ServerApplication on tower with PID 10644 (/home/dsyer/dev/demo/workspace/server/target/classes started by dsyer in /home/dsyer/dev/demo/workspace/server)
2020-02-24 10:45:33.182  INFO 1 --- [           main] com.example.ServerApplication            : No active profile set, falling back to default profiles: default
2020-02-24 10:45:33.776  INFO 1 --- [           main] o.s.b.web.embedded.netty.NettyWebServer  : Netty started on port(s): 8080
2020-02-24 10:45:33.778  INFO 1 --- [           main] com.example.ServerApplication            : Started ServerApplication in 25.758 seconds (JVM running for 31.943)
```

If you checkpoint there (re-using the same tag), you can restart the app really fast:

```
$ qemu-system-x86_64 -hda disk.qcow -boot d -net nic -net user,hostfwd=tcp::8080-:8080 -localtime -m 1024 -loadvm mytag
```

Remember to expose the host port (the first one listed in the `hostfwd`) as part of the network configuration. On the host:

```
$ curl localhost:8080
Hello World!!
```

Outstanding!

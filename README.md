# minicon - MINImization of the filesystems for CONtainers

When you run containers (e.g. in Docker), you usually run a system that has a whole Operating System and your specific application. The result is that the footprint of the container is bigger than needed.

**minicon** aims at reducing the footprint of the filesystem for the container, just adding those files that are needed. That means that the other files in the original container are removed.

The purpose of **minicon** is better understood with the use cases explained in depth in the section [Use Cases](#use-cases).

1. **Basic Example ([direct link](#use-case-basic-example))**, that distributes only the set of tools, instead of distributing a whole Linux image. In this case the size is reduced from 123Mb. to about 8Mb.
1. **Basic _user interface_ that need to access to other servers ([direct link](#use-case-basic-user-interface-ssh-cli-wget-vim))**. In this case we have reduced from 222Mb. to about 16Mb., and also we have made that the users only can use a reduced set of tools (ssh, ping, wget, etc.).
1. **Node.JS+Express application ([direct link](#use-case-nodejsexpress-application))**: The size of the defaut NodeJS Docker image (i.e. node:latest), ready to run an application is about from 691MB. Applying **minicon** to that container, the size is reduced to about 45.4MB.
1. **Use case: FFMPEG ([direct link](#use-case-ffmpeg))**: The size of a common _Ubuntu+FFMPEG_ image is about 387Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

## Why **minicon**?

Reducing the footprint of one container is of special interest, to redistribute the container images.

It is of special interest in cases such as [SCAR](https://github.com/grycap/scar), that try to execute docker containers in AWS Lambda. In that case, the use cases are limited by the size of the container (the filesystem is limited to 512 Mb., and SCAR needs to push the image to AWS Lambda and then uncompress it; so the maximum size for the container is even more restricted).

But there are also security reasons to minimize the unneeded application or environment available in one container image. In the case that the application fails, not having other applications reduces the impact of an intrusion (e.g. if the container does not need a compiler, why should it be there? maybe it would enable to compile a rootkit). 

In this sense, the recent publication of the NIST "[Application Container Security Guide](https://doi.org/10.6028/NIST.SP.800-190)" suggests that "_An image should only include the executables and libraries required by the app itself; all other OS functionality is provided by the OS kernel within the underlying host OS_".

## Installation

**minicon** is a bash script that tries to analize an application (or a set of applications) using other tools such as _ldd_ or _strace_. So you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **minicon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

### Dependencies

**minicon** depends on the commands _ldd_, _file_, _strace_ and _tar_. Soy you need to install the proper packages in your system.

**Ubuntu**

```bash
$ apt-get install libc-bin tar file strace
```

**CentOS**
```bash
$ yum install glibc-common tar file strace
```
## Usage

**minicon** has a lot of options. You are advised to run ```./minicon --help``` to get the latest information about the usage of the application.

The basic syntax is

```bash
$ ./minicon <option> <executables to analyze, files or folders to include>
```

Some options are:
- **--rootfs | -r**: Create the filesystem in a specific folder.
- **--tar-file | -t**: Generate a tar file that contains the resulting filesystem. This is ideal to import it into docker using the command ```docker import tarfile.tar containerimage```. If not specified the _--rootfs_ parameter, **minicon** will use a temporary folder.
- **--ldconfig | -l**: Generate a _/etc/ldconfig.so_ file, adjusted to the new filesystem. It is suggested to always use this flag, to set the proper path to the libraries included in the new filesystem.
- **--plugin**: Activates some plugins and sets the options for them (see the [Plug-ins](#plug-ins) section).
- **--plugin-all**: Activates all the available plugins, using their default options (see the [Plug-ins](#plug-ins) sub-section).
- **--verbose | -v**: Gives more information about the procedure.
- **--debug**: Gives a lot more information about the procedure.

### Usage in containers
**minicon** is very interesting for container images. You will probably have a container image that you will probably want to minimize. In this case, you should prepare a Dockerfile to ensure that you install the dependencies of **minicon**.

```Dockerfile
FROM mycontainer:ubuntu
RUN apt-get update && apt-get install libc-bin tar file strace
```

Then, you can build the container:

```bash
docker build . -t mycontainer:minicon
```

And finally, from the folder in which **minicon** is installed, you can run the analysis command (e.g. to create a filesystem that only contains _bash_, _ls_ and _mkdir_):

```bash
$ docker run --rm --plugin-all -it -v $PWD:/tmp/minicon mycontainer:minicon /tmp/minicon/minicon -l -t mycontainer_minimized.tar bash ls mkdir
```

Now you can import the resulting tarfile into Docker, and test it:

```bash
$ docker import mycontainer_minimized.tar mycontainer:minimized
$ docker run -it mycontainer:minimized bash
```

### Plug-ins

**minicon** includes two important plugins in the default distribution: _strace_ and _scripts_:

- **strace**: executes the applications for a while and tries to guess which files are they executing or using. Then these files are included in the filesystem (you have control on which paths should not be included).
- **scripts**: tries to guess if the executable is a script and include the interpreter (and its dependencies) in the filesystem.

To activate one plugin, you need to add the parameter ```--plugin```. The syntax is the next:

```bash
--plugin=<plugin-name>:<parameter1>=<value1>:<parameter2>=<value2>:<parameter2>=<value3>...
```

You can add as many ```--plugin``` entries as needed, in the call to **minicon**, and all of them will be considered in order (even if they refer to the same plugin).

> It is easy to extend the analysis that makes **minicon**, by simply implementing other plug-ins. If you are interested in creating a new one, you can inspect the source code or create an issue (the basic procedure to create a plugin is to create a function PLUGIN_XX_pluginname that gets a command or file as the first parameter).

#### strace plug-in
This plugin executes the applications for a while and tries to guess which files is executing or using. Then these files are included in **minicon** in order to be also included analyzed for inclusion in the resulting filesystem.

> In the case that you want to use **minicon** to analyze applications in a Docker container using the _strace_ plugin, is mandatory to run it as privileged (--privileged). Otherwise it will fail. It should not suppose any additional security problem, because it is a run-once analysis, and the resulting files will not require that the container is privileged (at least, because of **minicon**).

The execution of an application without any parameter may not represent the usage of the application. This is why you can include a file that contains example of full commandlines that should represent the usage of the application. These commandlines should contain information about executions that makes use of all the functions that you want to use from the application in the resulting filesystem.

> **Example**: The application _/usr/games/cowsay_ does nothing by itself, but if you pass a parameter, it loads perl and use some other files.

The file contains one commandline per line, for different executables. If several commandlines for the same executable are found in the file, **minicon** will use only the first of them.

> **Example**: /usr/games/cowsay "hello world"

To activate the strace plugin you can use the option ```--plugin```. Some examples are included below:

```bash
# The next execution will only try to execute the application cowsay for 3 seconds
$ ./minicon -t tarfile --plugin=strace /usr/games/cowsay
# The next execution will try to execute the application cowsay for 3 seconds, but will look for a commandline in the file "mycommand" in the current folder
$ ./minicon -t tarfile --plugin=strace:execfile=./mycommand  /usr/games/cowsay
# The next execution will try to execute the application cowsay for 10 seconds, and will look for a commandline in the file "mycommand" in the current folder
$ ./minicon -t tarfile --plugin=strace:seconds=10:execfile=./mycommand  /usr/games/cowsay
# The next execution will try to execute the application bash for 3 seconds (the default value), but will exclude any file used by the application that is found either in /dev or /proc
$ ./minicon -t tarfile --plugin=strace:exclude=/dev:exclude=/proc bash
```

#### scripts plug-in
Some of the executables that you want to include in the resulting filesystem can be scripts (e.g. bash, perl, python, etc.). As an example, **minicon** is a bash script. The problem is that these scripts need an interpreter (i.e. bash is needed for **minicon**), but inspecting the executable using _ldd_ will not find any dependency.

The scripts plug-in makes use of the _file_ command to guess whether the file is a script, and if it is, tries to guess which is the interpreter and includes it in the resulting filesystem.

To activate the strace plugin you can use the option ```--plugin```. Some examples are included below:

```bash
# The next call will try to identify whether the executable ./minicon is a script (it will find that it is), and will include /bin/bash in the filesystem.
$ ./minicon -t tarfile --plugin=scripts ./minicon
```

## Use Cases

This section includes the whole process to re-produce two use cases in which **minicon** can reduce the footprint of the size of the Docker containers.

1. Distributing only the set of tools needed for an _user interface_, instead of distributing a whole Linux image reduces the size from 123Mb. to about 8Mb.
1. Having a basic _user interface_ for the users, that need to access to other servers. In this case we have reduced from 222Mb. to about 16Mb., and also we have made that the users only can use a reduced set of tools (ssh, ping, wget, etc.).
1. A NodeJS application which is reduced from about 691MB to about 45.4MB.
1. The FFMPEG application which is reduced from about 387Mb. to about 119Mb.

### Use Case: Basic example
You can download the _ubuntu:latest_ docker image and check its size: 

```bash
$ docker pull ubuntu
Using default tag: latest
latest: Pulling from library/ubuntu
660c48dd555d: Pull complete 
4c7380416e78: Pull complete 
421e436b5f80: Pull complete 
e4ce6c3651b3: Pull complete 
be588e74bd34: Pull complete 
Digest: sha256:7c67a2206d3c04703e5c23518707bdd4916c057562dd51c74b99b2ba26af0f79
Status: Downloaded newer image for ubuntu:latest
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              latest              20c44cd7596f        2 weeks ago         123MB
```

A simple example will be to create a container that only contains a few commands (e.g. _bash_, _ls_, _mkdir_, etc.):

```bash
$ docker run --rm -it -v $PWD:/tmp/minicon ubuntu:latest /tmp/minicon/minicon -t /tmp/minicon/minibash.tar bash ls mkdir less cat find
[WARNING]  2017.12.05-12:45:24 disabling strace plugin because strace command is not available
[WARNING]  2017.12.05-12:45:24 disabling scripts plugin because file command is not available
```

Then you can import the container in Docker and check the difference of sizes:
```bash
$ docker import minibash.tar ubuntu:minibash
sha256:e4b5fa4f772d47b19ebe41544c52fd6c048a5a5d5abcac1d1e1efc30e3237025
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              minibash            e4b5fa4f772d        20 seconds ago      9.44MB
ubuntu              latest              20c44cd7596f        2 weeks ago         123MB
```

The size has been reduced dramatically, but **of course** you only have the requested files inside the container.

```bash
$ tar tf minibash.tar 
$ docker run --rm -it ubuntu:minibash find /bin /lib /usr /lib64
$ docker run --rm -it ubuntu:minibash ls /
```

<details>
 <summary>Click to show the whole execution (for verification purposes).</summary>

```bash
$ tar tf minibash.tar 
./
./bin/
./bin/cat
./bin/ls
./bin/mkdir
./bin/bash
./tmp/
./proc/
./lib/
./lib/x86_64-linux-gnu/
./lib/x86_64-linux-gnu/libpcre.so.3
./lib/x86_64-linux-gnu/libc-2.23.so
./lib/x86_64-linux-gnu/libc.so.6
./lib/x86_64-linux-gnu/libdl.so.2
./lib/x86_64-linux-gnu/libm.so.6
./lib/x86_64-linux-gnu/libtinfo.so.5
./lib/x86_64-linux-gnu/libtinfo.so.5.9
./lib/x86_64-linux-gnu/libm-2.23.so
./lib/x86_64-linux-gnu/libpthread.so.0
./lib/x86_64-linux-gnu/libselinux.so.1
./lib/x86_64-linux-gnu/ld-2.23.so
./lib/x86_64-linux-gnu/libdl-2.23.so
./lib/x86_64-linux-gnu/libpthread-2.23.so
./lib/x86_64-linux-gnu/libpcre.so.3.13.2
./usr/
./usr/bin/
./usr/bin/find
./lib64/
./lib64/ld-linux-x86-64.so.2
./dev/
$ docker run --rm -it ubuntu:minibash find /bin /lib /usr /lib64
/bin
/bin/cat
/bin/ls
/bin/mkdir
/bin/bash
/lib
/lib/x86_64-linux-gnu
/lib/x86_64-linux-gnu/libpcre.so.3
/lib/x86_64-linux-gnu/libc-2.23.so
/lib/x86_64-linux-gnu/libc.so.6
/lib/x86_64-linux-gnu/libdl.so.2
/lib/x86_64-linux-gnu/libm.so.6
/lib/x86_64-linux-gnu/libtinfo.so.5
/lib/x86_64-linux-gnu/libtinfo.so.5.9
/lib/x86_64-linux-gnu/libm-2.23.so
/lib/x86_64-linux-gnu/libpthread.so.0
/lib/x86_64-linux-gnu/libselinux.so.1
/lib/x86_64-linux-gnu/ld-2.23.so
/lib/x86_64-linux-gnu/libdl-2.23.so
/lib/x86_64-linux-gnu/libpthread-2.23.so
/lib/x86_64-linux-gnu/libpcre.so.3.13.2
/usr
/usr/bin
/usr/bin/find
/lib64
/lib64/ld-linux-x86-64.so.2
$ docker run --rm -it ubuntu:minibash ls /
bin  dev  etc  lib  lib64  proc  sys  tmp  usr
```
</details>

### Use Case: Basic User Interface (SSH Cli, wget, vim)

In this use case we are building a basic user interface for the users, that need to access to other servers. The users will need commands like _ssh_, _wget_, _ping_, etc.

In the general case, we will use a Dockerfile like the next one:

```Dockerfile
FROM ubuntu
RUN apt-get update && apt-get install -y ssh iproute2 iputils-ping wget
```

And we will build using the next command:

```bash
$ docker build . -t basic-ui
```

Now we have the container image called ```basic-ui``` that will serve for our purposes. We can inspect its size:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
basic-ui            latest              58acd895d8d1        2 minutes ago       222MB
```

But we can reduce the size, if we know which tools we want to provide to our users. From the folder in which it is installed **minicon**, we can execute the following commands to minimize the container and to import it into docker:

```
$ cat > ./execfile-cmd << EOF
ssh localhost
/usr/bin/ssh localhost
/bin/ping -c 1 www.google.es
EOF
$ docker run --privileged --rm -it -v $PWD:/tmp/minicon basic-ui bash -c 'apt-get install -y strace && /tmp/minicon/minicon -t /tmp/minicon/basic-ui-min.tar -l --plugin=strace:execfile=/tmp/minicon/execfile-cmd bash ssh ip id cat ls mkdir ping wget'
$ docker import basic-ui-min.tar basic-ui:lean
```

> In this case we needed to use the plugin _strace_ to guess which files are needed for the applications. E.g. the libraries for DNS resolution, configuration files, etc. So we created some simple examples of commandlines for some of the applications that we are including in the container.

And now we have a container with a very reduced size:

```
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
basic-ui            lean                21e481217b6c        8 seconds ago       16MB
basic-ui            latest              58acd895d8d1        7 minutes ago       222MB
```

In this case we have reduced from 222Mb. to about 16Mb., and also we have made that the users only can use a reduced set of tools.

### Use Case: Node.JS+Express application
**TL;DR:** the image of a NodeJS+Express application can be reduced from 691MB (using the standard image of node; i.e. _node:latest_) to 45.4MB (just including the node environment).

If you have a _NodeJS+Express_ application, it is possible to redistribute it using Docker.

We can create a basic application using express (called _miniapp_):

```bash
$ express miniapp$ express miniapp

  warning: the default view engine will not be jade in future releases
  warning: use `--view=jade' or `--help' for additional options


   create : miniapp
   create : miniapp/package.json
   create : miniapp/app.js
   (...)
   create : miniapp/public/stylesheets
   create : miniapp/public/stylesheets/style.css

   install dependencies:
     $ cd miniapp && npm install

   run the app:
     $ DEBUG=miniapp:* npm start

   create : miniapp/public/images
```

Now we can create a Dockerfile (inside the _miniapp_ folder) like the next one to redistribute our _miniapp_ NodeJS+Express application:

```Docker
FROM node:latest

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install app dependencies
COPY package.json /usr/src/app/
RUN npm install

# Bundle app source
COPY . /usr/src/app

EXPOSE 3000
```

And now we can build the application and run it:
```bash
$ docker build . -t miniapp
Sending build context to Docker daemon  7.218MB
Step 1/8 : FROM node:latest
 ---> c1d02ac1d9b4
(...)
Step 8/8 : CMD npm start
 ---> Using cache
 ---> feb69da10e8b
Successfully built feb69da10e8b
Successfully tagged miniapp:latest
$ docker run --rm -it -w /usr/src/app -p 3000:3000 miniapp node bin/www
```

From other terminal you can chech that it is possible to get the contents
```bash
$ curl -o- http://localhost:3000
<!DOCTYPE html><html><head><title>Express</title><link rel="stylesheet" href="/stylesheets/style.css"></head><body><h1>Express</h1><p>Welcome to Express</p></body></html>
```

If you inspect the size of the miniapp image, you will see something like the next:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
node                latest              c1d02ac1d9b4        13 days ago         676MB
miniapp             latest              feb69da10e8b        43 minutes ago      691MB
```

The _node:latest_ image contains a whole debian distribution, but we only want to run a NodeJS+Express application

#### Stripping all the unneeded files

We are using **minicon** to strip out any other things but the files that we need to run our application. From the **minicon** folder we can start the Docker container that we want to minimize:

```
~/minicon$ docker run --rm -p 3000 -it -v $PWD:/tmp/minicon -w /tmp/minicon miniapp bash
```

And now run **minicon** to get only de files needed (take into account that now we need the interpreter (node) and the app folder (i.e. /usr/src/app)):
```
root@2ed82c5454a9:/tmp/minicon# ./minicon -l -t miniapp.tar node /usr/src/app
[WARNING] 2017.11.29-18:15:18 disabling strace plugin because strace command is not available
root@2ed82c5454a9:/tmp/minicon# exit
```

And finally we can create the container that only contains the NodeJS interpreter and our NodeJS+Express application:
```
~/minicon$ docker import miniapp.tar miniapp:lean
sha256:82624eebfc0b0b9f7cdb9959c8d372ccf06573f94578d4ef717f463a70f5fcb7
~/minicon$ docker run --rm -it -w /usr/src/app -p 3000:3000 miniapp:lean node bin/www
```

And it is possible to interact with the application.

The difference comes when you check the size of the new image compared to the previous one:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
miniapp             lean                82624eebfc0b        5 minutes ago       45.4MB
node                latest              c1d02ac1d9b4        13 days ago         676MB
miniapp             latest              feb69da10e8b        43 minutes ago      691MB
```

In this case we have reduced the size of the container from 691MB to 45.4MB.

### Use case: FFMPEG
**TL;DR:** The size of a common _Ubuntu+FFMPEG_ image is about 387Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

Imagine that you want to run the latest version of the app _ffmpeg_ to convert your video files. The usual way to proceed will consist of

1. Creating a Docker file with a content like the next one:

```Dockerfile
FROM ubuntu
RUN apt-get -y update && apt-get -y install ffmpeg
```

2. Building the container

```bash
$ docker build . -t ubuntu:ffmpeg
```

3. Run the application

```bash
$ docker run --rm -it -v /myvideos:/tmp/myvideos ubuntu:ffmpeg ffmpeg /tmp/myvideos ...
```

This usual procedure is ok, but if you take a look at the size of the image, you will find something like the next:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              ffmpeg              816069cb64a1        5 days ago          387MB
ubuntu              latest              2fa927b5cdd3        18 months ago       122MB
```

The problem is that in the image ```ubuntu:ffmpeg``` you have both _ffmpeg_ and the whole _ubuntu:latest_ base operating system. You will not run any other app appart from _ffmpeg_ (i.e. you do not need _mount_, _ssh_, _tar_, _rm_, etc.), but they are there:

```bash
$ docker run --rm -it ubuntu:ffmpeg ls -l /bin
total 7360
-rwxr-xr-x 1 root root 1037464 Aug 31  2015 bash
-rwxr-xr-x 1 root root   52080 Feb 18  2016 cat
-rwxr-xr-x 1 root root   60272 Feb 18  2016 chgrp
-rwxr-xr-x 1 root root   56112 Feb 18  2016 chmod
-rwxr-xr-x 1 root root   64368 Feb 18  2016 chown
-rwxr-xr-x 1 root root  151024 Feb 18  2016 cp
-rwxr-xr-x 1 root root  154072 Feb 17  2016 dash
-rwxr-xr-x 1 root root   68464 Feb 18  2016 date
-rwxr-xr-x 1 root root   72632 Feb 18  2016 dd
-rwxr-xr-x 1 root root   97912 Feb 18  2016 df
-rwxr-xr-x 1 root root  126584 Feb 18  2016 dir
-rwxr-xr-x 1 root root   60680 Apr 13  2016 dmesg
lrwxrwxrwx 1 root root       8 Nov 24  2015 dnsdomainname -> hostname
lrwxrwxrwx 1 root root       8 Nov 24  2015 domainname -> hostname
-rwxr-xr-x 1 root root   31376 Feb 18  2016 echo
-rwxr-xr-x 1 root root      28 Apr  5  2016 egrep
...
```

**minicon** can reduce the footprint of the filesystem by only including the application _ffmpeg_ and those libraries and files needed by _ffmpeg_.

#### Stripping all the unneeded files
From the **minicon** commandline you can start a container that has the _ffmpeg_ application, and map the **minicon** folder:

```bash
$ docker run --rm -it -v $PWD:/tmp/minicon ubuntu:ffmpeg bash
```

There you will get to the shell inside the container. And now you can start the minimization of the filesystem by issuing the next command:

```
root@c41b836e6f77:/# /tmp/minicon/minicon --ldconfig --tarfile /tmp/minicon/miniffmpeg.tar ffmpeg
[WARNING] 2017.11.29-15:30:47 disabling strace plugin because strace command is not available
[WARNING] 2017.11.29-15:30:47 disabling scripts plugin because file command is not available
root@c41b836e6f77:/# exit
user@ubuntu:~/minicon$ ls -l
total 116116
-rw-rw-r-- 1 user     user     11357 nov 29 15:20 LICENSE
-rwxrwxr-x 1 user     user     11988 nov 29 16:30 minicon
-rwxrwxr-x 1 user     user      2418 nov 29 16:08 minicondocker
-rw-r--r-- 1 root     root     118886400 nov 29 16:30 miniffmpeg.tar
-rw-rw-r-- 1 user     user      3408 nov 29 16:31 README.md
```

The result is that you have a tar file that contains a filesystem that only includes _ffmpeg_ and the libraries needed to run it.

Now you can import the filesystem into Docker and run _ffmpeg_ but this time from the new minified container:

```
user@ubuntu:~/minicon$ docker import miniffmpeg.tar ffmpeg:mini
sha256:3eac8bc3a29bcffb462b1b24dbd6377b4f94b009b18a1846dd83022beda7e3f8
user@ubuntu:~/minicon$ docker run --rm -it ffmpeg:mini ffmpeg
ffmpeg version 2.8.11-0ubuntu0.16.04.1 Copyright (c) 2000-2017 the FFmpeg developers
  built with gcc 5.4.0 (Ubuntu 5.4.0-6ubuntu1~16.04.4) 20160609
  configuration: --prefix=/usr --extra-version=0ubuntu0.16.04.1 --build-suffix=-ffmpeg --toolchain=hardened --libdir=/usr/lib/x86_64-linux-gnu --incdir=/usr/include/x86_64-linux-gnu --cc=cc --cxx=g++ --enable-gpl --enable-shared --disable-stripping --disable-decoder=libopenjpeg --disable-decoder=libschroedinger --enable-avresample --enable-avisynth --enable-gnutls --enable-ladspa --enable-libass --enable-libbluray --enable-libbs2b --enable-libcaca --enable-libcdio --enable-libflite --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libgme --enable-libgsm --enable-libmodplug --enable-libmp3lame --enable-libopenjpeg --enable-libopus --enable-libpulse --enable-librtmp --enable-libschroedinger --enable-libshine --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libssh --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libvpx --enable-libwavpack --enable-libwebp --enable-libx265 --enable-libxvid --enable-libzvbi --enable-openal --enable-opengl --enable-x11grab --enable-libdc1394 --enable-libiec61883 --enable-libzmq --enable-frei0r --enable-libx264 --enable-libopencv
  libavutil      54. 31.100 / 54. 31.100
  libavcodec     56. 60.100 / 56. 60.100
  libavformat    56. 40.101 / 56. 40.101
  libavdevice    56.  4.100 / 56.  4.100
  libavfilter     5. 40.101 /  5. 40.101
  libavresample   2.  1.  0 /  2.  1.  0
  libswscale      3.  1.101 /  3.  1.101
  libswresample   1.  2.101 /  1.  2.101
  libpostproc    53.  3.100 / 53.  3.100
Hyper fast Audio and Video encoder
usage: ffmpeg [options] [[infile options] -i infile]... {[outfile options] outfile}...

Use -h to get full help or, even better, run 'man ffmpeg'
```

You can verify that the footprint of the container has been reduced:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              ffmpeg              816069cb64a1        5 days ago          387MB
ubuntu              latest              2fa927b5cdd3        18 months ago       122MB
ffmpeg              mini                3eac8bc3a29b        About a minute ago   119MB
```

The size of the common _Ubuntu+FFMPEG_ image is about 387Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

# Manipulation of Container Filesystems

This file explains [**minicon**](#1-minicon---minimization-of-the-filesystems-for-containers), [**mergecon**](#2-mergecon---merge-container-filesystems) and [**importcon**](#3-importcon---import-container-copying-features):

1. **minidock** ([direct link]()) analyzes one existing Docker image, reduces its footprint and leaves the new version in the local Docker registry. It makes use of the other tools in the _minicon_ package.

1. **minicon** ([direct link](#2-minicon---minimization-of-the-filesystems-for-containers)) aims at reducing the footprint of the filesystem for the container, just adding those files that are needed. That means that the other files in the original container are removed.

1. **importcon** ([direct link](#3-importcon---import-container-copying-features)) importcon is a tool that imports the contents from a tarball to create a filesystem image using the "docker import" command. But it takes as reference an existing docker image to get parameters such as ENV, USER, WORKDIR, etc. to set them for the new imported image.

1. **mergecon** ([direct link](#4-mergecon---merge-container-filesystems)) is a tool that merges the filesystems of two different container images. It creates a new container image that is built from the combination of the layers of the filesystems of the input containers.

# 1. MiniDock - minimization of Docker containers

When you run Docker containers, you usually run a system that has a whole Operating System and your specific application. The result is that the footprint of the container is bigger than needed.

**minidock** aims at reducing the footprint of the Docker containers, by just including in the container those files that are needed. That means that the other files in the original container are removed.

The purpose of **minidock** is better understood with the use cases explained in depth in the section "[Examples](#14-examples)": the size of an Apache server is reduced from 216MB. to 50.4MB., and the size of a Perl application in a Docker container is reduced from 206MB to 50.4MB.


> **minidock** is based on [**minicon**](#1-minicon---minimization-of-the-filesystems-for-containers), [**importcon**](#3-importcon---import-container-copying-features) and [**mergecon**](#2-mergecon---merge-container-filesystems), and hides the complexity of creating a container, mapping minicon, guessing parameters such as the entrypoint or the default command, creating the proper commandline, etc.

## 1.1 Why **minidock**?

Reducing the footprint of one container is of special interest, to redistribute the container images and saving the storage space in your premises. There are also security reasons to minimize the unneeded application or environment available in one container image (e.g. if the container does not need a compiler, why should it be there? maybe it would enable to compile a rootkit). 

In this sense, the recent publication of the NIST "[Application Container Security Guide](https://doi.org/10.6028/NIST.SP.800-190)" suggests that "_An image should only include the executables and libraries required by the app itself; all other OS functionality is provided by the OS kernel within the underlying host OS_".

**minicon** is a tool that enables a fine grain minimization for any type of container (it is even interesting for non containerized boxes). Using it for Docker images consist in a simple pipeline:

1. Preparing a Docker container with the dependencies of **minicon**
1. Guessing the entrypoint and the default command for the container.
1. Running **minicon** for these commands (maping the proper folders to get the resulting tar file).
1. Using **importcon** to import the resulting file to copy the entrypoint and other settings.
1. etc.

**minidock** is a one-liner for that procedure whose aim is just to convert a

```bash
$ docker run --rm -it myimage myapp
``` 

into

```bash
$ minicon -i myimage -t myimage:minicon -- myapp
``` 

To obtain the minimized Docker image, and hiding the internal procedure.

## 1.2 Installation

**minidock** is a bash script that runs the other applications in the _minicon_ package, to analyze the docker containers. So you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **minidock** application. Then the commands in the _minicon_ distribution must be in the PATH. So I would suggest to put it in the _/opt_ folder and set the proper PATH var. Otherwise leave it in a folder of your choice and set the PATH variable:

```bash
$ mv minicon /opt
$ export PATH=$PATH:/opt/minicon
```

### 1.2.1 Dependencies

**minidock** depends on the commands _minicon_, _importcon_ and _mergecon_, and the packages _jq_, _tar_ and _docker_. So, you need to install the proper packages in your system.

**Ubuntu**

```bash
$ apt-get install jq tar 
```

**CentOS**
```bash
$ yum install tar jq which
```
## 1.3 Usage

**minidock** has a lot of options. You are advised to run ```./minidock --help``` to get the latest information about the usage of the application.

The basic syntax is

```bash
$ ./minidock <options> <options for minicon> [ --docker-opts <options for docker> ] -- <run for the container>
```

Some of the options are:
- \<run for the container\>: Is the whole commandline to be analised in the run. These are the same parameters that you would pass to "docker run ... <image> <run for the container>". 
> * the aim is that you run "minidock" as if you used a "docker run" for your container.
- **\<options for docker\>**: If you need them, you can include some options that will be raw-passed to the docker run command used during the analysis. (i.e. minidock will executedocker run <options generated> <options for docker> ...). Some examples are mapping volumes (i.e. **-v** Docker flag)
- **\<options for minicon\>**: If you need to, you can add some minicon-specific options. The supported options are --include --exclude --plugin: --exclude will exclude some path, --include will include specific files or folder, and --plugin can be used to configure the _minicon_ plugins.
- **--image \<image\>**: Name of the existing Docker image to minimize.
- **--tag \<tag\>**: Tag for the resulting image (random if not provided).
- **--default-cmd**: Analyze the default command for the containers in the original image.
- **--apt**: Install the dependencies from minicon using apt-get commands (in the container used for the simulation).
- **--yum**: Install the dependencies from minicon using yum commands (in the container used for the simulation).
- **--execution \<full commandline execution\>**: Commandline to analyze when minimizing the container (i.e. that commandline should be able to be executed in the resulting container so the files, libraries, etc. needed should be included). 
- **--run \<full commandline run\>**: Similar to _--execution_, but in this case, the Entrypoint is prepended to the commandline (docker exec vs docker run).
- **-2 \<image\>**: If needed, you can merge the resulting minimized image with other. This is very specific for the "mergecon" tool. It is useful for (e.g.) adding a minimal Alpine distro (with _ash_ and so on) to the minimized filesystem.
- **--verbose | -v**: Gives more information about the procedure.
- **--debug**: Gives a lot more information about the procedure.

## 1.4 Examples

The distibution include two examples for the usage of **minidock**. They are in the _usecases/uc5_ and _usecases/uc6_ folders.

### 1.4.1. Apache server

In order to have an apache server, according to the Docker docs, you can create the following Dockerfile:

```docker
FROM ubuntu
RUN apt-get update && apt-get install -y --force-yes apache2
EXPOSE 80 443
VOLUME ["/var/www", "/var/log/apache2", "/etc/apache2"]
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

Then you can build it and run it:

```bash
$ docker build . -t minicon:uc5fat
...
$ docker run -id -p 10000:80 minicon:uc5fat
fe20ebce12f2d5460bb0191975450833117528987c32c95849315bc4330c0f2a
$ wget -q -O- localhost:10000 | head -n 3

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
```

In this case, the size of the image is about 261MB:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc5fat              ff6f2573d73b        9 days ago          261MB
```

In order to reduce it, you just need to issue the next command:
```bash
$ ./minidock -i minicon:uc5fat -t minicon:uc5 --apt
...
```

> The flag _--apt_ instructs **minidock** to install the dependencies of minicon using apt-get commands, inside one ephemeral container that will be used for the analysis. It is also possible to use _--yum_, instead of _--apt_.

And you will have the minimized apache ready to be run:

```bash
$ docker run --rm -id -p 10001:80 minicon:uc5
0e0ef746586fd632877f1c9344b42b4dbb00f52dc2a5d06028cbfa72bd297d6c
$ wget -q -O- localhost:10001 | head -n 3

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
```

But in this case, the footprint of the apache image has been reduced to 50.4MB:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
minicon             uc5                 f577e1f6e3f8        About a minute ago   50.4MB
minicon             uc5fat              ff6f2573d73b        9 days ago           261MB
```

### 1.4.2 cowsay: Docker image with Entrypoint with parameters

In order to have a simple cowsay application you can create the following Dockerfile:

```docker
FROM ubuntu
RUN apt-get update && apt-get install -y cowsay
ENTRYPOINT ["/usr/games/cowsay"]
```

Then you can build it and run it:

```bash
$ docker build . -t minicon:uc6fat
...
$ docker run --rm -it minicon:uc6fat i am a cow in a fat container
 _______________________________
< i am a cow in a fat container >
 -------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

In this case, the entrypoint needs some parameters to be run. If you try to analyze the container simply issuing a command like the next one:

```bash
$ ./minidock -i minicon:uc6fat -t minicon:uc6 --apt
...
$ docker run --rm -it minicon:uc6 i am a cow in a not properly minimized container
cowsay: Could not find default.cow cowfile!
```

It does not work properly, because the execution of the entrypoint has not been successfully simulated (cowsay needs some parameters to run).

In this case, you should run a **minidock** commandline that include the command that we used to test it, and we will be able to run it:

```bash
$ ./minidock -i minicon:uc6fat -t minicon:uc6 --apt -- i am a cow in a fat container
...
$ docker run --rm -it minicon:uc6 i am a cow in a minimized container
 _____________________________________
< i am a cow in a minimized container >
 -------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

> after the -- flag, we can include those parameters that we use in a docker run execution.

We can check the differences in the sizes:

```bash
$ docker images minicon
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc6                 7c85b5a104f5        5 seconds ago       43.3MB
minicon             uc6fat              1c8179d3ba94        4 hours ago         206MB
```

In this case, the size has been reduced from 206MB to about 43.3MB.

# 2. minicon - MINImization of the filesystems for CONtainers

When you run containers (e.g. in Docker), you usually run a system that has a whole Operating System and your specific application. The result is that the footprint of the container is bigger than needed.

**minicon** aims at reducing the footprint of the filesystem for the container, just adding those files that are needed. That means that the other files in the original container are removed.

The purpose of **minicon** is better understood with the use cases explained in depth in the section [Use Cases](#24-use-cases).

1. **Basic Example ([direct link](#use-case-basic-example))**, that distributes only the set of tools, instead of distributing a whole Linux image. In this case the size is reduced from 123Mb. to about 5.54Mb.
1. **Basic _user interface_ that need to access to other servers ([direct link](#use-case-basic-user-interface-ssh-cli-wget))**. In this case we have reduced from 222Mb. to about 11Mb., and also we have made that the users only can use a reduced set of tools (ssh, ping, wget, etc.).
1. **Node.JS+Express application ([direct link](#use-case-nodejsexpress-application))**: The size of the defaut NodeJS Docker image (i.e. node:latest), ready to run an application is about from 691MB. Applying **minicon** to that container, the size is reduced to about 45.3MB.
1. **Use case: FFMPEG ([direct link](#use-case-ffmpeg))**: The size of a common _Ubuntu+FFMPEG_ image is about 388Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

## 2.1 Why **minidock**?

Reducing the footprint of one container is of special interest, to redistribute the container images.

It is of special interest in cases such as [SCAR](https://github.com/grycap/scar), that executes containers out of Docker images in AWS Lambda. In that case, the use cases are limited by the size of the container (the ephemeral storage space is limited to 512 Mb., and SCAR needs to pull the image from Docker Hub into the ephemeral storage and then uncompress it; so the maximum size for the container is even more restricted).

But there are also security reasons to minimize the unneeded application or environment available in one container image. In the case that the application fails, not having other applications reduces the impact of an intrusion (e.g. if the container does not need a compiler, why should it be there? maybe it would enable to compile a rootkit). 

In this sense, the recent publication of the NIST "[Application Container Security Guide](https://doi.org/10.6028/NIST.SP.800-190)" suggests that "_An image should only include the executables and libraries required by the app itself; all other OS functionality is provided by the OS kernel within the underlying host OS_".

## 2.2 Installation

**minicon** is a bash script that tries to analize an application (or a set of applications) using other tools such as _ldd_ or _strace_. So you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **minicon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

### 2.2.1 Dependencies

**minicon** depends on the commands _ldd_, _file_, _strace_, _rsync_ and _tar_. So, you need to install the proper packages in your system.

**Ubuntu**

```bash
$ apt-get install libc-bin tar file strace rsync
```

**CentOS**
```bash
$ yum install glibc-common tar file strace rsync which
```
## 2.3 Usage

**minicon** has a lot of options. You are advised to run ```./minicon --help``` to get the latest information about the usage of the application.

The basic syntax is

```bash
$ ./minicon <option> <executables to analyze, files or folders to include>
```

Some options are:
- **--rootfs | -r**: Create the filesystem in a specific folder.
- **--tar-file | -t**: Generate a tar file that contains the resulting filesystem. This is ideal to import it into Docker using the command ```docker import tarfile.tar containerimage```. If not specified the _--rootfs_ parameter, **minicon** will use a temporary folder.
- **--ldconfig | -l**: Generate a _/etc/ldconfig.so_ file, adjusted to the new filesystem. It is suggested to always use this flag, to set the proper path to the libraries included in the new filesystem.
- **--plugin**: Activates some plugins and sets the options for them (see the [Plug-ins](#plug-ins) section).
- **--plugin-all**: Activates all the available plugins, using their default options (see the [Plug-ins](#plug-ins) sub-section).
- **--execution | -E**: Executes the commandline included as parameter (e.g. ```-E "ping -c 1 www.google.es"```). This is specially useful for the strace plugin. It is possible to pass parameters to the _strace_ command plugin using the format "\<parameters\>,\<commandline\>" (e.g. ```-E "seconds=60,ping -c 1 www.google.es"``` will strace the ping for 60 seconds).
- **--exclude | -e**: Exclude all paths that begin with the parameter (e.g. ```-e "/root/.ssh"```). This parameter can be included more that once.
- **--verbose | -v**: Gives more information about the procedure.
- **--debug**: Gives a lot more information about the procedure.

### 2.3.1 Usage of minicon in containers
**minicon** is very interesting for container images, in special Docker images. You have the tool **minidock** that will help you to reduce Docker images, and I will suggest to use it.

In case that you want to reduce one container by yourself, you should prepare a Dockerfile to ensure that you install the dependencies of **minicon**.

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

### 2.3.2 Plug-ins

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

The execution of an application without any parameter may not represent the usage of the application. This is why you can use the parameter ```-E``` to include commandlines that would represent the usage of the application. These commandlines should contain information about executions that makes use of all the functions that you want to use from the application in the resulting filesystem.

> **Example**: The application _/usr/games/cowsay_ does nothing by itself, but if you pass a parameter, it loads perl and use some other files. You can use the parameter ```-E "/usr/games/cowsay hello"``` to run it.

To activate the strace plugin you can use the option ```--plugin```. Some examples are included below:

```bash
# The next execution will only try to execute the application cowsay for 3 seconds
$ ./minicon -t tarfile --plugin=strace -E '/usr/games/cowsay hello'
# The next execution will try to execute the application cowsay for 3 seconds, but will look for a commandline in the file "mycommand" in the current folder
$ ./minicon -t tarfile --plugin=strace:seconds=10 -E '/usr/games/cowsay hello'
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

> **DISCLAIMER**: take into account that the _scripts_ plugin is an automated tool and tries to make its best. If a interpreter is detected, all the default include folder for that interpreter will be added to the final filesystem. If you know your app, you can reduce the number of folders to include. 

## 2.4 Use Cases

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
ubuntu              latest              20c44cd7596f        3 weeks ago         123MB
```

A simple example will be to create a container that only contains a few commands (e.g. _bash_, _ls_, _mkdir_, etc.):

```bash
$ docker run --rm -it -v $PWD:/tmp/minicon ubuntu:latest /tmp/minicon/minicon -t /tmp/minicon/usecases/uc1/uc1.tar -E bash -E ls -E mkdir -E less -E cat -E find
[WARNING]  2017.12.05-12:45:24 disabling strace plugin because strace command is not available
[WARNING]  2017.12.05-12:45:24 disabling scripts plugin because file command is not available
[WARNING] [LDD] 2018.02.21-11:00:31 rsync is not available... some file permissions will be lost
/bin/bash
/bin/ls
/bin/mkdir
/bin/cat
/usr/bin/find
/lib/x86_64-linux-gnu/libselinux.so.1
/lib/x86_64-linux-gnu/libtinfo.so.5.9
/lib/x86_64-linux-gnu/libdl-2.23.so
/lib/x86_64-linux-gnu/libc-2.23.so
/lib/x86_64-linux-gnu/ld-2.23.so
/lib/x86_64-linux-gnu/libpcre.so.3.13.2
/lib/x86_64-linux-gnu/libpthread-2.23.so
/lib/x86_64-linux-gnu/libm-2.23.so
ldconfig recreated
```

Then you can import the container in Docker and check the difference of sizes:
```bash
$ docker import usecases/uc1/uc1.tar minicon:uc1
sha256:267c7ff2b27eabaaf931e5b0a7948c6545c176737cc2953bb030a696ef42d83d
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc1                 267c7ff2b27e        Less than a second ago   5.54MB
ubuntu              latest              20c44cd7596f        3 months ago        123MB
```

The size has been reduced dramatically, but **of course** you only have the requested files inside the container.

```bash
$ tar tf usecases/uc1/uc1.tar 
$ docker run --rm -it minicon:uc1 find /bin /lib /usr /lib64
$ docker run --rm -it minicon:uc1 ls /
```

<details>
 <summary>Click to show the whole execution (for verification purposes).</summary>

```bash
$ tar tf usecases/uc1/uc1.tar 
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
$ docker run --rm -it minicon:uc1 find /bin /lib /usr /lib64
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
$ docker run --rm -it minicon:uc1 ls /
bin  dev  etc  lib  lib64  proc  sys  tmp  usr
```
</details>

### Use Case: Basic User Interface (SSH Cli, wget)

In this use case we are building a basic user interface for the users, that need to access to other servers. The users will need commands like _ssh_, _wget_, _ping_, etc.

In the general case, we will use a Dockerfile like the next one (in folder ./usecases/uc2):

```Dockerfile
FROM ubuntu
RUN apt-get update && apt-get install -y ssh iproute2 iputils-ping wget
```

And we will build using the next command:

```bash
$ docker build ./usecases/uc2/. -t minicon:uc2fat
```

Now we have the container image called ```minicon:uc2fat``` that will serve for our purposes. We can inspect its size:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc2fat              2a95d52068fd        2 minutes ago       222MB
```

But we can reduce the size, if we know which tools we want to provide to our users. From the folder in which it is installed **minicon**, we can execute the following commands to minimize the container and to import it into docker:

```
$ docker run --privileged --rm -it -v /home/calfonso/Programacion/git/minicon:/tmp/minicon minicon:uc2fat bash -c 'apt-get install -y strace && /tmp/minicon/minicon -t /tmp/minicon/usecases/uc2/uc2.tar --plugin=strace:execfile=/tmp/minicon/usecases/uc2/execfile-cmd -E bash -E ssh -E ip -E id -E cat -E ls -E mkdir -E ping -E wget'
$ docker import usecases/uc2/uc2.tar minicon:uc2
```

> In this case we needed to use the plugin _strace_ to guess which files are needed for the applications. E.g. the libraries for DNS resolution, configuration files, etc. So we created some simple examples of commandlines for some of the applications that we are including in the container.

And now we have a container with a very reduced size:

```
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc2                 9d8e0cacd383        Less than a second ago   10.8MB
minicon             uc2fat              2a95d52068fd        2 minutes ago       222MB
```

In this case we have reduced from 222Mb. to about 11Mb., and also we have made that the users only can use a reduced set of tools.

### Use Case: Node.JS+Express application
**TL;DR:** the image of a NodeJS+Express application can be reduced from 691MB (using the standard image of node; i.e. _node:latest_) to 45.3MB (just including the node environment).

If you have a _NodeJS+Express_ application, it is possible to redistribute it using Docker.

We can create a basic application using express (called _miniapp_):

```bash
$ express ./usecases/uc3/miniapp

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
COPY miniapp/package.json /usr/src/app/
RUN npm install

# Bundle app source
COPY miniapp /usr/src/app

EXPOSE 3000
```

And now we can build the application and run it:
```bash
$ docker build ./usecases/uc3 -t minicon:uc3fat
Sending build context to Docker daemon  7.218MB
Step 1/8 : FROM node:latest
 ---> c1d02ac1d9b4
(...)
Step 8/8 : CMD npm start
 ---> Using cache
 ---> feb69da10e8b
Successfully built feb69da10e8b
Successfully tagged miniapp:uc3fat
$ docker run --rm -it -w /usr/src/app -p 3000:3000 minicon:uc3fat node bin/www
```

From other terminal you can check that it is possible to get the contents
```bash
$ curl -o- http://localhost:3000
<!DOCTYPE html><html><head><title>Express</title><link rel="stylesheet" href="/stylesheets/style.css"></head><body><h1>Express</h1><p>Welcome to Express</p></body></html>
```

If you inspect the size of the built image, you will see something like the next:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc3fat              80168974cfa4        4 minutes ago       685MB
node                latest              c1d02ac1d9b4        13 days ago         676MB
```

The _node:latest_ image contains a whole debian distribution, but we only want to run a NodeJS+Express application

#### Stripping all the unneeded files

We are using **minicon** to strip out any other things but the files that we need to run our application. From the **minicon** folder we can start the Docker container that we want to minimize:

```
~/minicon$ docker run --rm -p 3000 -it -v $PWD:/tmp/minicon -w /tmp/minicon miniapp bash
```

And now run **minicon** to get only the files needed (take into account that now we need the interpreter (node) and the app folder (i.e. /usr/src/app)):
```
root@2ed82c5454a9:/tmp/minicon# ./minicon -l -t /tmp/minicon/usecases/uc3/uc3.tar -E node -I /usr/src/app
[WARNING] 2017.11.29-18:15:18 disabling strace plugin because strace command is not available
[WARNING] [FOLDER] 2018.02.21-12:29:10 rsync is not available... some file permissions will be lost
/usr/src/app
/usr/local/bin/node
/lib/x86_64-linux-gnu/libgcc_s.so.1
/lib/x86_64-linux-gnu/libdl-2.19.so
/lib/x86_64-linux-gnu/librt-2.19.so
/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.20
/lib/x86_64-linux-gnu/libm-2.19.so
/lib/x86_64-linux-gnu/libpthread-2.19.so
/lib/x86_64-linux-gnu/libc-2.19.so
/lib/x86_64-linux-gnu/ld-2.19.so
ldconfig recreated
root@2ed82c5454a9:/tmp/minicon# exit
```

And finally we can create the container that only contains the NodeJS interpreter and our NodeJS+Express application:
```
~/minicon$ docker import usecases/uc3/uc3.tar minicon:uc3
sha256:73f77fa9fca0192e843523e6fb12c5bdcb79fb85768de751435dbfe642a4b611
~/minicon$ docker run --rm -it -w /usr/src/app -p 3000:3000 minicon:uc3 node bin/www
```

And it is possible to interact with the application.

The difference comes when you check the size of the new image compared to the previous one:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc3                 73f77fa9fca0        Less than a second ago   45.3MB
minicon             uc3fat              80168974cfa4        4 minutes ago       685MB
node                latest              c1d02ac1d9b4        13 days ago         676MB
```

In this case we have reduced the size of the container from 691MB to 45.3MB.

### Use case: FFMPEG
**TL;DR:** The size of a common _Ubuntu+FFMPEG_ image is about 388Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

Imagine that you want to run the latest version of the app _ffmpeg_ to convert your video files. The usual way to proceed will consist of:

1. Creating a Docker file with a content like the next one (located in ```./usecases/uc4```):

```Dockerfile
FROM ubuntu
RUN apt-get -y update && apt-get -y install ffmpeg
```

2. Building the container

```bash
$ docker build . -t minicon:uc4fat
```

3. Run the application

```bash
$ docker run --rm -it -v /myvideos:/tmp/myvideos minicon:uc4fat ffmpeg /tmp/myvideos ...
```

This usual procedure is ok, but if you take a look at the size of the image, you will find something as follows:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             uc4fat              1ce54cdefdce        Less than a second ago   388MB
ubuntu              latest              20c44cd7596f        3 weeks ago         123MB
```

The problem is that in the image ```ubuntu:ffmpeg``` you have both _ffmpeg_ and the whole _ubuntu:latest_ base operating system. You will not run any other app appart from _ffmpeg_ (i.e. you do not need _mount_, _ssh_, _tar_, _rm_, etc.), but they are there:

```bash
$ docker run --rm -it minicon:uc4fat ls -l /bin
total 7364
-rwxr-xr-x 1 root root 1037528 May 16  2017 bash
-rwxr-xr-x 1 root root   52080 Mar  2  2017 cat
-rwxr-xr-x 1 root root   60272 Mar  2  2017 chgrp
-rwxr-xr-x 1 root root   56112 Mar  2  2017 chmod
-rwxr-xr-x 1 root root   64368 Mar  2  2017 chown
-rwxr-xr-x 1 root root  151024 Mar  2  2017 cp
-rwxr-xr-x 1 root root  154072 Feb 17  2016 dash
-rwxr-xr-x 1 root root   68464 Mar  2  2017 date
-rwxr-xr-x 1 root root   72632 Mar  2  2017 dd
-rwxr-xr-x 1 root root   97912 Mar  2  2017 df
-rwxr-xr-x 1 root root  126584 Mar  2  2017 dir
-rwxr-xr-x 1 root root   60680 Jun 14 21:51 dmesg
lrwxrwxrwx 1 root root       8 Nov 24  2015 dnsdomainname -> hostname
lrwxrwxrwx 1 root root       8 Nov 24  2015 domainname -> hostname
-rwxr-xr-x 1 root root   31376 Mar  2  2017 echo
-rwxr-xr-x 1 root root      28 Apr 29  2016 egrep
...
```

**minicon** can reduce the footprint of the filesystem by only including the application _ffmpeg_ and those libraries and files needed by _ffmpeg_.

#### Stripping all the unneeded files
From the **minicon** commandline you can start a container that has the _ffmpeg_ application, start the minimization of the filesystem by issuing the next command:

```bash
$ docker run --rm -it -v $PWD:/tmp/minicon minicon:uc4fat /tmp/minicon/minicon --ldconfig --tarfile /tmp/minicon/usecases/uc4/uc4.tar -E ffmpeg 
[WARNING] 2017.11.29-15:30:47 disabling strace plugin because strace command is not available
[WARNING] 2017.11.29-15:30:47 disabling scripts plugin because file command is not available
```

The result is that you have a tar file that contains a filesystem that only includes _ffmpeg_ and the libraries needed to run it.

Now you can import the filesystem into Docker and run _ffmpeg_ but this time from the new minified container:

```
user@ubuntu:~/minicon$ docker import usecases/uc4/uc4.tar minicon:uc4
sha256:3eac8bc3a29bcffb462b1b24dbd6377b4f94b009b18a1846dd83022beda7e3f8
user@ubuntu:~/minicon$ docker run --rm -it minicon:uc4 ffmpeg
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
minicon             uc4                 c3ae3608e431        1 second ago        119MB
minicon             uc4fat              1ce54cdefdce        Less than a second ago   388MB
ubuntu              latest              20c44cd7596f        3 weeks ago         123MB
```

The size of the common _Ubuntu+FFMPEG_ image is about 388Mb., but if you apply **minicon** on that image, you will get a working _ffmpeg_ container whose size is only about 119Mb.

# 3. importcon - IMPORT CONtainer copying features

When a container is running, it is possible to export its filesystem to a tar file, using the command ```docker export <mycontainer>```. Later, it is possible to import that filesystem into Docker to be used as a Docker image, using a command like ```docker import <mytarfile>```. The problem is that the new container has lost all the parameters from the original image (i.e. ENTRYPOINT, USER, CMD, etc.).

**importcon** is a script that enables to import a filesystem exported using ```docker export``` into Docker, and to copy the parameters from the original image (i.e. ENTRYPOINT, USER, CMD, VOLUME, etc.)

## 3.1 Why importcon?

If you create a minimal application filesystem (i.e. using **minicon**), you will get a tarfile that contains the minified filesystem. Then you will probably import it into Docker using the command ```docker import``` (as in the examples). The problem is that the new container will not keep the settings such as ENTRYPOINT, CMD, WORKDIR, etc.

Using **importcon**, you will be able to import the obtainer tarfile into Docker, but it is possible to provide the name of an existing image as a reference, to copy its parameters (ENV, ENTRYPOINT, CMD, WORKDIR, etc.).

## 3.2 Installation

**importcon** is a bash script that deals with **docker** commands. **importcon** is part of the **minicon** package, and so you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **importcon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

### 3.2.1 Dependencies

**importcon** depends on the commands _jq_. So, you need to install the proper packages in your system. 

**Ubuntu**

```bash
$ apt-get install jq
```

**CentOS**
```bash
$ yum install jq
```
## 3.3 Usage

**importcon** has a lot of options. You are advised to run ```./importcon --help``` to get the latest information about the usage of the application.

The basic syntax is

```bash
$ ./importcon <options> <container filesystem in tar file> 
```

- **--image | -i <image>**: Name of the existing image to copy the parameters.
- **--tag | -t <tag>**: Tag for the image that will be created from the tarfile (random if not provided)
- **--env | -E**: Copy ENV settings
- **--entrypoint | -e**: Copy ENTRYPOINT settings
- **--expose | -x**: Copy EXPOSE settings
- **--onbuild | -o**: Copy ONBUILD settings
- **--user | -u**: Copy USER settings
- **--volume | -V**: Copy VOLUME settings
- **--workdir | -w**: Copy WORKDIR settins
- **--cmd | -c**: Copy CMD settings
- **--all | -A**: Copy all the previous settings: ENV, ENTRYPOINT, EXPOSE, ONBUILD, USER, VOLUME, WORKDIR and CMD.
- **--help | -h**: Shows this help and exits.

## 3.4 Example

If we take the next Dockerfile

```docker
FROM ubuntu
RUN apt-get update && apt-get install -y --force-yes apache2
EXPOSE 80 443
VOLUME ["/var/www", "/var/log/apache2", "/etc/apache2"]
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

and we build it using the command

```bash
docker build . -t tests:apache
Sending build context to Docker daemon  37.89kB
Step 1/5 : FROM ubuntu
 ---> 20c44cd7596f
Step 2/5 : RUN apt-get update && apt-get install -y --force-yes apache2
 ...
Successfully built ff6f2573d73b
Successfully tagged tests:apache
```

Then we can run a container

```bash
$ docker run --rm -id -p 10000:80 tests:apache
54cd115ab56afc0446b796336ffbfe4415a27f27c6379d0f3d526d79b7e0396b

$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                            NAMES
54cd115ab56a        tests:apache        "/usr/sbin/apache2..."   4 seconds ago       Up 2 seconds        443/tcp, 0.0.0.0:10000->80/tcp   hungry_payne
```

And export its filesystem to a file:

```bash
$ docker export hungry_payne -o myapache.tar
```

If we import the file back to a Docker image
```bash
$ docker import myapache.tar tests:myapache
sha256:397cc8e14785e4b5819348f99850cca6b641602bac319457d539ec51ec468a9e
```

Now we can check the differences between the configuration of each image for the new containers:

```bash
$ docker inspect tests:apache | jq '.[0].Config'
{
  "Hostname": "85a5c35750d6",
  "Domainname": "",
  "User": "",
  "AttachStdin": false,
  "AttachStdout": false,
  "AttachStderr": false,
  "ExposedPorts": {
    "443/tcp": {},
    "80/tcp": {}
  },
  "Tty": false,
  "OpenStdin": false,
  "StdinOnce": false,
  "Env": [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  ],
  "Cmd": null,
  "ArgsEscaped": true,
  "Image": "sha256:9bd5b7f04adcd3b7c8fce216e7c3b190abb8941e62acbba72a9172b0b50adf00",
  "Volumes": {
    "/etc/apache2": {},
    "/var/log/apache2": {},
    "/var/www": {}
  },
  "WorkingDir": "",
  "Entrypoint": [
    "/usr/sbin/apache2ctl",
    "-D",
    "FOREGROUND"
  ],
  "OnBuild": [],
  "Labels": {}
}

$ docker inspect tests:myapache | jq '.[0].Config'
{
  "Hostname": "",
  "Domainname": "",
  "User": "",
  "AttachStdin": false,
  "AttachStdout": false,
  "AttachStderr": false,
  "Tty": false,
  "OpenStdin": false,
  "StdinOnce": false,
  "Env": null,
  "Cmd": null,
  "Image": "",
  "Volumes": null,
  "WorkingDir": "",
  "Entrypoint": null,
  "OnBuild": null,
  "Labels": null
}
```

We can see that our new image has all the setting set to empty. So if we run the container from our new image, the command will fail (because of the lack of the ENTRYPOINT setting):

```bash
$ docker run --rm -id -p 10001:80 tests:myapache
docker: Error response from daemon: No command specified.
See 'docker run --help'.
```

If we import the image using **importcon** and we inspect the configuration:

```bash
$ ./importcon -t tests:apacheimportcon -i tests:apache myapache.tar -A
tests:apacheimportcon
sha256:2319eb385a2be7be1e7f0409ec923643b3273427963ecc0e33f2d067f969a66a

$ docker inspect tests:apacheimportcon | jq '.[0].Config'
{
  "Hostname": "",
  "Domainname": "",
  "User": "",
  "AttachStdin": false,
  "AttachStdout": false,
  "AttachStderr": false,
  "ExposedPorts": {
    "443/tcp": {},
    "80/tcp": {}
  },
  "Tty": false,
  "OpenStdin": false,
  "StdinOnce": false,
  "Env": [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  ],
  "Cmd": null,
  "Image": "",
  "Volumes": {
    "/etc/apache2": {},
    "/var/log/apache2": {},
    "/var/www": {}
  },
  "WorkingDir": "",
  "Entrypoint": [
    "/usr/sbin/apache2ctl",
    "-D",
    "FOREGROUND"
  ],
  "OnBuild": null,
  "Labels": null
}
```

We see that the settings (in special, the ENTRYPOINT) have been copied from the original _tests:apache_ image. And now we are able to run the container as we did in the original one:

```bash
$ docker run --rm -id -p 10001:80 tests:apacheimportcon
6081218d246e0106915a876374a276378912335d3a843f09305939bdd4cd4832
$ docker ps
CONTAINER ID        IMAGE                   COMMAND                  CREATED             STATUS              PORTS                            NAMES
6081218d246e        tests:apacheimportcon   "/usr/sbin/apache2..."   7 seconds ago       Up 6 seconds        443/tcp, 0.0.0.0:10001->80/tcp   naughty_brattain
```

# 4. mergecon - MERGE CONtainer filesystems

Docker containers are built from different layers, and **mergecon** is a tool that merges the filesystems of two different container images. It creates a new container image that is built from the combination of the layers of the filesystems of the input containers.

## 4.1 Why mergecon?

If you create a minimal application filesystem (i.e. using **minicon**), you will be able to run your application, but you will not have any other application available for (e.g.) debugging your application.

Using **mergecon**, you will be able to overlay the files of your container image to other existing container image. In this way, you can overlay your **minicon** resulting application over a whole **ubuntu:latest** container. The effect is that you will have the support of a whole operating environment over the minimal container.

### 4.1.2 Other use cases
1. Even getting the resulting image by applying **minicon** over an **ubuntu:latest** derived container, you can overlay such image over an **alpine:latest** image (or other). The effect is that you will have your application over an **alpine** host. This is of interest in case that you want to run GNU applications over non-GNU systems(e.g. alpine).

1. If you have an application that needs to be compiled and installed, you can create a one-liner installation, and combine that layer with other container. That means that you will be able to compile such image in (e.g.) ubuntu, and create a final container with other flavor (e.g. CentOS).

## 4.2 Installation

**mergecon** is a bash script that deals with **docker** commands. **mergecon** is part of the **minicon** package, and so you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **mergecon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

### 4.2.1 Dependencies

**mergecon** depends on the commands _tar_ and _jq_. So, you need to install the proper packages in your system. 

**Ubuntu**

```bash
$ apt-get install tar jq
```

**CentOS**
```bash
$ yum install tar jq
```
## 4.3 Usage

**mergecon** has a lot of options. You are advised to run ```./mergecon --help``` to get the latest information about the usage of the application.

The basic syntax is

```bash
$ ./mergecon <options> 
```

Some options are:
- **--first | -1 <image>**: Name of the first container image (will use docker save to dump it)
- **--second | -2 <image>**: Name of the second container image (will use docker save to dump it) the default behaviour gives more priority to the second image. I.e. in case of overlapping files in both input images, the files in the second image will be exposed to the final image.
- **--tag | -t <name>**: Name of the resulting container image. If not provided, the resulting name will be the concatenation of the names of the two input images: <image1>:<image2> (the : in the input image names is removed).
- **--working | -w <folder>**: Working folder. If not provided will create a temporary folder in /tmp
- **--list | -l**: Lists the layers in the images (useful for filesystem composition).
- **--file | -f <file>**: tar file where the resulting image will be created. If not provided, the image will be loaded into docker.
- **--keeptemporary | -k**: Keeps the temporary folder. Otherwise, the folder is removed (if it is created by mergecon).
- **--verbose | -v**: Gives more information about the procedure.
- **--debug**: Gives a lot more information about the procedure.


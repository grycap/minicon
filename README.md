# minicon - minimization containers

When you run containers (e.g. in Docker), you usually run a system that has a whole Operating System, documentation, extra packages, etc. and your specific application. The result is that the footprint of the container is bigger than needed.

**minicon** is a general tool to analyze applications and executions of these applications to obtain a filesystem that contains all the dependencies that have been detected. In particular, it can be used to reduce Docker containers. The **minicon** package includes **minidock**
which will help to reduce Docker containers by hiding the underlying complexity of running **minicon** inside a Docker container.

The purpose of **minicon** and **minidock** is better understood with the use cases explained in depth in the section "[Examples](#4-examples)": the size of a basic UI that contains bash, ip, wget, ssh, etc. commands is _reduced from 211MB to 10.9MB_; the size of a NodeJS application along with the server is _reduced from 686 MB (using the official node image) to 45.6MB_; the size of an Apache server is _reduced from 216MB to 50.4MB_, and the size of a Perl application in a Docker container is _reduced from 206MB to 5.81MB_.

> [**minidock**](doc/minidock.md) is based on [**minicon**](doc/minicon.md), [**importcon**](doc/importcon.md) and [**mergecon**](doc/mergecon.md), and hides the complexity of creating a container, mapping minicon, guessing parameters such as the entrypoint or the default command, creating the proper commandline, etc.

## 1. Why **minicon** and **minidock**?

Reducing the footprint of one container is of special interest, to redistribute the container images.

It is of special interest in cases such as [SCAR](https://github.com/grycap/scar), that executes containers out of Docker images in AWS Lambda. In that case, the use cases are limited by the size of the container (the ephemeral storage space is limited to 512 Mb., and SCAR needs to pull the image from Docker Hub into the ephemeral storage and then uncompress it; so the maximum size for the container is even more restricted).

But there are also security reasons to minimize the unneeded application or environment available in one container image. In the case that the application fails, not having other applications reduces the impact of an intrusion (e.g. if the container does not need a compiler, why should it be there? maybe it would enable to compile a rootkit). 

In this sense, the recent publication of the NIST "[Application Container Security Guide](https://doi.org/10.6028/NIST.SP.800-190)" suggests that "_An image should only include the executables and libraries required by the app itself; all other OS functionality is provided by the OS kernel within the underlying host OS_".

**minicon** is a tool that enables a fine grain minimization for any type of filesystem, but it is possible to use it to reduce Docker images following the next pipeline:

1. Preparing a Docker container with the dependencies of **minicon**
1. Guessing the entrypoint and the default command for the container.
1. Running **minicon** for these commands (maping the proper folders to get the resulting tar file).
1. Using **importcon** to import the resulting file to copy the entrypoint and other settings.
1. etc.

**minidock** is a one-liner that automates that procedure to make that reducing a container consist in just to convert a

```bash
$ docker run --rm -it myimage myapp
``` 

into

```bash
$ minidock -i myimage -t myimage:minicon -- myapp
``` 

## 2. Installation

### 2.1 From packages

You can get the proper package (.deb o .rpm) from the [Releases page](https://github.com/grycap/minicon/releases) and install it using the appropriate package manager.

**Ubuntu/Debian**

```bash
$ apt update
$ apt install ./minicon-1.2-1.deb
```

[![asciicast](https://asciinema.org/a/165792.png)](https://asciinema.org/a/165792)

**CentOS/Fedora/RedHat**

```bash
$ yum install epel-release
$ yum install ./minicon-1.2-1.noarch.rpm
```

[![asciicast](https://asciinema.org/a/166107.png)](https://asciinema.org/a/166107)

### 2.2 From sources

**minicon** are a set of bash scripts. So you just simply need to have a working linux with bash and the other dependencies installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **minicon**, **minidock** and other applications. The commands in the _minicon_ distribution must be in the PATH. So I would suggest to put it in the _/opt_ folder and set the proper PATH var. Otherwise leave it in a folder of your choice and set the PATH variable:

```bash
$ mv minicon /opt
$ export PATH=$PATH:/opt/minicon
```

#### 2.2.1 Dependencies

**minidock** depends on the commands _minicon_, _importcon_ and _mergecon_, and the packages _jq_, _tar_ and _docker_. **minicon** and the others have dependencies on other packages. So, you need to install the proper packages in your system:

**Ubuntu**

```bash
$ apt-get install jq tar libc-bin tar file strace rsync
```

**CentOS**
```bash
$ yum install tar jq glibc-common file strace rsync which
```

## 3. Usage

The **minidock suite** enables to prepare filesystems for running containers. The suite consists in the next commands: 

1. **minidock** ([doc](doc/minidock.md)) analyzes one existing Docker image, reduces its footprint and leaves the new version in the local Docker registry. It makes use of the other tools in the _minicon_ package.

1. **minicon** ([doc](doc/minicon.md)) aims at reducing the footprint of the filesystem for the container, just adding those files that are needed. That means that the other files in the original container are removed.

1. **importcon** ([doc](doc/importcon.md)) importcon is a tool that imports the contents from a tarball to create a filesystem image using the "docker import" command. But it takes as reference an existing docker image to get parameters such as ENV, USER, WORKDIR, etc. to set them for the new imported image.

1. **mergecon** ([doc](doc/mergecon.md)) is a tool that merges the filesystems of two different container images. It creates a new container image that is built from the combination of the layers of the filesystems of the input containers.

Please refer to the documentation of each command to get help about them.

## 4. Examples

In this section we are including examples on using **minidock**, that makes use of all the other commands. Please refer to the documentation of each command to get examples about each individual command.

### 4.1 Basic Ubuntu UI in less than 11 Mb.

In this example we will create a basic user interface, from ubuntu, that include commands like `wget`, `ssh`, `cat`, etc.

The `ubuntu:latest` image do not contain such commands. So we need to create a Docker file that installs `wget`, `ssh`, `ping` and others. We will use this Dockerfile:

```dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y ssh iproute2 iputils-ping wget
```

And now, we will build the image by issuing the next command:

```bash
$ docker build . -t minicon:ex1fat
```

> At this point you can check the image, and the commands that it has. You just need to create a container and issue the commands that you want to check: `docker run --rm -it minicon:ex1fat bash`

Once that we have the image, we will minimize it by issuing the next command:

```bash
$ minidock -i minicon:ex1fat -t minicon:ex1 --apt -E bash -E 'ssh localhost' \
-E ip -E id -E cat -E ls -E mkdir \
-E 'ping -c 1 www.google.es' -- wget www.google.es
```

* Each `-E` flag includes an example of the execution that we want to be able to make in the minimized image.
* The `--apt` flag is included because we want to minimize an apt-based image (that instructs **minidock** to resolve the dependencies inside the container, using apt commands)
* The command after `--` is one of the command lines that we should be able to execute in the resulting image.

Finally you can verify that the image has drammatically reduced its size:

```bash
$ docker images minicon
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             ex1                 42a532b9c262        28 minutes ago      10.9MB
minicon             ex1fat              d3498d9cf260        30 minutes ago      211MB
```

At this point you should be able to run one container, using the resulting image:

```dockerfile
$ docker run --rm -it minicon:ex1 bash
```

The whole procedure can be seen in the next asciicast:

[![asciicast](https://asciinema.org/a/165798.png)](https://asciinema.org/a/165798)

### 4.2 Basic CentOS 7 in about 16 Mb.

In this example we will create the same use-case than in the previous one, but based on a CentOS image: a basic CentOS-based user interface, that include commands like `wget`, `ssh`, `cat`, etc.

The `centos:latest` image do not contain the needed commands. So we need to create a Docker file that installs `wget`, `ssh`, `ping` and others. We will use this Dockerfile:

```dockerfile
FROM centos:latest
RUN yum -y update && yum install -y iproute iputils openssh-clients wget
```

And now, we will build the image by issuing the next command:

```bash
$ docker build . -t minicon:ex1fat
```

> At this point you can check the image, and the commands that it has. You just need to create a container and issue the commands that you want to check: `docker run --rm -it minicon:ex1fat bash`

Once that we have the image, we will minimize it by issuing the next command:

```bash
$ minidock -i minicon:ex1fat -t minicon:ex1 --yum -E bash -E 'ssh localhost' \
-E ip -E id -E cat -E ls -E mkdir \
-E 'ping -c 1 www.google.es' -- wget www.google.es
```

* Each `-E` flag includes an example of the execution that we want to be able to make in the minimized image.
* The `--yum` flag is included because we want to minimize a yum-based image (that instructs **minidock** to resolve the dependencies inside the container used for simulation, using yum commands)
* The command after `--` is one of the command lines that we should be able to execute in the resulting image.

Finally you can verify that the image has drammatically reduced its size:

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
minicon             ex1                 43d11b4837dd        About a minute ago   16MB
minicon             ex1fat              66c5aa5bb77b        3 minutes ago        362MB
centos              latest              ff426288ea90        7 weeks ago          207MB
```

At this point you should be able to run one container, using the resulting image:

```dockerfile
$ docker run --rm -it minicon:ex1 bash
```

The whole procedure can be seen in the next asciicast:

[![asciicast](https://asciinema.org/a/166112.png)](https://asciinema.org/a/166112)

### 4.3 NodeJS application

In this example, we will start from the default NodeJS image and will pack our freshly created application.

In first place we are creating an application using express (for our purposes, we are using the default application):

```bash
$ express myapp
```

To dockerize this nodejs application, you can use the default [node image at docker hub](https://hub.docker.com/_/node/), which is based on Debian, and use the next Dockerfile:

```dockerfile
FROM node
COPY myapp /usr/app/myapp
WORKDIR /usr/app/myapp
RUN npm install
ENTRYPOINT node ./bin/www
EXPOSE 3000
```

Now we can build our application and test it:

```bash
$ docker build . -t minicon:ex2fat
$ docker run --rm -id -p 10000:3000 minicon:ex2fat
5cb83644120c074f799e2ba802f09690054eae48fdb44d92094550de4f895702                                                                                    $ wget -q -O- http://localhost:10000
<!DOCTYPE html><html><head><title>Express</title><link rel="stylesheet" href="/stylesheets/style.css"></head><body><h1>Express</h1><p>Welcome to Express</p></body></html>
```

Once that we have our application, we can minimize it:

```bash
$ minidock --apt -i minicon:ex2fat -t minicon:ex2 -I /usr/app/myapp
```

* The `--apt` flag is included because the original image is based on debian (that instructs **minidock** to resolve the dependencies inside the container, using apt commands)
* We do not need to include any command to simulate because the original image has an entrypoint defined, which will be simulated.
* In this example we are not running all the possibilities of our application during the simulation, but we know that the application is stored in `/usr/app/myapp` and that the global modules 

We can test the image:

```bash
$ docker run --rm -id -p 10001:3000 minicon:ex2 
fedb5c972e8e47ac02c09661f767156aa88328b1ce72646e717bd60624adefda     
$ wget -q -O- http://localhost:10001
<!DOCTYPE html><html><head><title>Express</title><link rel="stylesheet" href="/stylesheets/style.css"></head><body><h1>Express</h1><p>Welcome to Express</p></body></html>calfonso@ubuntu:~/ex2$                  
```

If we check the size of the original and the minimized images, we can see that it has been reduced from 686 MB. to 45.6MB. (which is even less than the official node:alpine image).
```bash
$ docker images                                                      
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
minicon             ex2                 1080e761a83c        38 seconds ago      45.6MB                                             
minicon             ex2fat              7f8bef02d321        4 minutes ago       686MB
node                alpine              a88ff852e3d4        4 days ago          68MB
node                latest              29831ba76d93        4 days ago          676MB
```

The whole procedure can be seen in the next asciicast:

[![asciicast](https://asciinema.org/a/166058.png)](https://asciinema.org/a/166058)


### 4.4 Apache server

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

### 4.5 cowsay: Docker image with Entrypoint with parameters

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
minicon             uc6                 7c85b5a104f5        5 seconds ago       5.81MB
minicon             uc6fat              1c8179d3ba94        4 hours ago         206MB
```

In this case, the size has been reduced from 206MB to about 5.81MB.

# importcon - IMPORT CONtainer copying features

When a container is running, it is possible to export its filesystem to a tar file, using the command ```docker export <mycontainer>```. Later, it is possible to import that filesystem into Docker to be used as a Docker image, using a command like ```docker import <mytarfile>```. The problem is that the new container has lost all the parameters from the original image (i.e. ENTRYPOINT, USER, CMD, etc.).

**importcon** is a script that enables to import a filesystem exported using ```docker export``` into Docker, and to copy the parameters from the original image (i.e. ENTRYPOINT, USER, CMD, VOLUME, etc.)

## 1. Why importcon?

If you create a minimal application filesystem (i.e. using **minicon**), you will get a tarfile that contains the minified filesystem. Then you will probably import it into Docker using the command ```docker import``` (as in the examples). The problem is that the new container will not keep the settings such as ENTRYPOINT, CMD, WORKDIR, etc.

Using **importcon**, you will be able to import the obtainer tarfile into Docker, but it is possible to provide the name of an existing image as a reference, to copy its parameters (ENV, ENTRYPOINT, CMD, WORKDIR, etc.).

## 2. Installation

### 2.1 From packages

You can get the proper package (.deb o .rpm) from the [Releases page](https://github.com/grycap/minicon/releases) and install it using the appropriate package manager.

**Ubuntu/Debian**

```bash
$ apt update
$ apt install ./minicon-1.2-1.deb
```

**CentOS/Fedora/RedHat**

```bash
$ yum install epel-release
$ yum install ./minicon-1.2-1.noarch.rpm
```

### 2.2. From sources

**importcon** is a bash script that deals with **docker** commands. **importcon** is part of the **minicon** package, and so you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **importcon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

#### 2.2.1 Dependencies

**importcon** depends on the commands _jq_. So, you need to install the proper packages in your system. 

**Ubuntu**

```bash
$ apt-get install jq
```

**CentOS**
```bash
$ yum install jq
```
## 3. Usage

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

## 4. Example

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

# mergecon - MERGE CONtainer filesystems

Docker containers are built from different layers, and **mergecon** is a tool that merges the filesystems of two different container images. It creates a new container image that is built from the combination of the layers of the filesystems of the input containers.

## 1. Why mergecon?

If you create a minimal application filesystem (i.e. using **minicon**), you will be able to run your application, but you will not have any other application available for (e.g.) debugging your application.

Using **mergecon**, you will be able to overlay the files of your container image to other existing container image. In this way, you can overlay your **minicon** resulting application over a whole **ubuntu:latest** container. The effect is that you will have the support of a whole operating environment over the minimal container.

### 1.2 Other use cases
1. Even getting the resulting image by applying **minicon** over an **ubuntu:latest** derived container, you can overlay such image over an **alpine:latest** image (or other). The effect is that you will have your application over an **alpine** host. This is of interest in case that you want to run GNU applications over non-GNU systems(e.g. alpine).

1. If you have an application that needs to be compiled and installed, you can create a one-liner installation, and combine that layer with other container. That means that you will be able to compile such image in (e.g.) ubuntu, and create a final container with other flavor (e.g. CentOS).

## 2. Installation

**mergecon** is a bash script that deals with **docker** commands. **mergecon** is part of the **minicon** package, and so you just simply need to have a working linux with bash installed and get the code:

```bash
$ git clone https://github.com/grycap/minicon
```

In that folder you'll have the **mergecon** application. I would suggest to put it in the _/opt_ folder. Otherwise leave it in a folder of your choice:

```bash
$ mv minicon /opt
```

### 2.1 Dependencies

**mergecon** depends on the commands _tar_ and _jq_. So, you need to install the proper packages in your system. 

**Ubuntu**

```bash
$ apt-get install tar jq
```

**CentOS**
```bash
$ yum install tar jq
```
## 3. Usage

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


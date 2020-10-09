# Deploy Ezmeral Container Platform on KVM

## What & Why
To re-utilize scripts and processes by https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/

## Pre-requisites
- CentOS/RHEL 7+ (tested on CentOS 8.2 Host)
- libvirt, qemu-kvm, libvirt-client, virt-install
- Python3, openssh, nc, curl, ipcalc, hpecp
- Passwordless sudo

## Prepare environment
- KVM & Qemu
```bash
sudo dnf install -y qemu-kvm libvirt libvirt-client
```
- virt-install
```bash
sudo dnf install -y virt-install
```
- python3 & pip3
```bash
sudo dnf install -y python3
```
- ssh-keygen
```bash
sudo dnf install -y openssh
```
- nc
```bash
sudo dnf install -y nmap-ncat
```
- curl
```bash
sudo dnf install -y curl
```
- ipcalc
```bash
pip3 install --user ipcalc six
```
- hpecp
```bash
pip3 install --user hpecp
```
- Edit sudoers file



### Collect and customize
```bash
git clone https://github.com/hpe-container-platform-community/hcp-demo-env-kvm-bash.git 
cd hcp-demo-env-kvm-bash
vi etc/kvm_config.sh
```

> <code>PROJECT_DIR=_this_</code>

> <code>CENTOS_IMAGE_FILE=_path-to-local CentOS-7-x86_64-GenericCloud-2003.qcow2_</code>

> <code>LOCAL_YUM_REPO=_url_</code> # Not used now

> <code>BEHIND_PROXY=True|False</code> # This defines if we setup env vars for proxy for tools such as yum, wget, curl etc</code>

> <code>PROXY_URL=_url_ (if BEHIND_PROXY=True)</code>

> <code>LOCALREPO=_url to .repo file_ ! should be replacing LOCAL_YUM_REPO var above</code>

> <code>TIMEZONE=_your time zone in ?? format_ ie, "Asia/Dubai"</code>

> <code>EPIC_FILENAME="path-to-epic-installer"</code>

> <code>EPIC_DL_URL=_url_</code> # to download EPIC_FILENAME

> <code>IMAGE_CATALOG=_url_</code> # to download EPIC images if you want to use local image repo

> <code>CREATE_EIP_GATEWAY=True|False</code> # to enable/disable IP forwarding to gateway # work in progress


### OPTIONAL # If you want customization
> <code>DOMAIN="ecp.demo"</code>

> <code>VIRTUAL_NET_NAME="ecpnet"</code>

> <code>NET=10.1.10</code> # Use this notation x.x.x (skip last dot as it will be added)
> <code>BRIDGE=virbr10</code>

<pre># Define hosts in a rather strange way</pre>
> <code>hosts=('controller' 'gw' 'host1' 'host2' 'host3')</code> # hostnames are hard coded (avoid using name gateway as it is resolving to KVM host within VMs)
> <code>cpus=(16 4 8 8 8)</code>

> <code>mems=(65536 32768 65536 65536 65536)</code>

<pre># assign roles (for proper configuration script)</pre>
<pre># possible roles: controller gateway worker ad rdp mapr1 mapr2</pre>
> <code>roles=('controller' 'gateway' 'worker' 'worker' 'worker')</code>

<pre># disk sizes (data disk size per host)</pre>
> <code>disks=(512 0 512 512 512)</code>

### Installation

Run
```bash
./bin/kvm_create_new_environment.sh
```

Wait for completion (45 min to 1.5h)

ssh scripts/commands will be copied to <code>./generated</code> directory. And connectivity information will be displayed as part of script output.

```bash
./generated/ssh_controller.sh
./generated/ssh_gw.sh
```

Open a browser to gateway (if CREATE_EIP_GATEWAY enabled an ip forwarding rule to ports 80/443/8080 will be created for local KVM host)
> https://gw.ecp.demo


# TODO

- [x] Test with non-root user

- [ ] Selectively deploy K8s cluster or EPIC cluster

- [ ] Attach to GPU on host

- [x] Public IP via host interface

- [ ] Enable RDP host

- [ ] Enable external MapR cluster

- [ ] Clean up (unneeded variables etc)

- [ ] Optimizations (less reboots, less modifications to source scripts etc)

- [ ] Enable local YUM repo (nfs to avoid downloading packages)

- [ ] Enable mounted image catalog (nfs to avoid copying catalog images)

# Troubleshooting 

If you get error for backing disk not accessible "Permission denied", be sure that SE allows permission to all the way up to the backing file _/full/path/to/centos.qcow2_

Replace the full path: <code>sudo setfacl -m u:qemu:rx /full/path/to/</code>
If file is on NFS share: <code>sudo setsebool virt_use_nfs on</code>


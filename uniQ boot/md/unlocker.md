# unlocker Xen domain (operator console)
name = "unlocker"
memory = 256
vcpus = 1
disk = [ 'file:/var/lib/xen/images/unlocker.img,xvda,w' ]
vif = [ 'bridge=br0' ]
on_poweroff = 'destroy'
on_reboot = 'restart'
on_crash = 'restart'
extra = "vchan-port=9003"
# unlocker connects to cryptod:vchan on port 9001

```ini name=xen/hardened/policy_pd.cfg
# policy_pd hardened Xen domain (example)
name = "policy_pd"
memory = 128
maxmem = 128
vcpus = 1
disk = [ 'file:/var/lib/xen/images/policy_pd.img,xvda,r' ]
vif = [ 'bridge=br0,ip=10.0.0.6' ]
extra = "vchan-port=9004;vchan-allowed-domids=3" # only cryptod issues tokens
pci = []
untrusted = 0
```

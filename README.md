# Script to run some commands on fresh Raspberry Pis

These are a few steps we'll definitely need to take with
any new Raspbian Lite install. There are only two prerequisites
to using this installer:

- `touch /boot/ssh` to enable SSH on boot
- some form of internet connection (e.g. `wpa_supplicant.conf`)
- get the IP address of the Pi (from router or manually with a monitor)

myip = `ifconfig -a | grep broadcast | awk '{print $2}'`
initialips = `nmap -sn #{myip}-255 | grep report | awk '{print $5}'`

- Set the password to something reasonable.
- Set the hostname in /etc/hostname and /etc/hosts
- mkdir -p ~/.ssh; chmod 700 ~/.ssh
- Copy authorized_keys
- chmod 600 ~/.ssh/authorized_keys
- Set static IP address
- Setup and share /var/hostname-data if USB storage attached
- Write hostname, ip and shared path to pis.yml

RaspberryPi hostnames will be generated sequentially starting with `pidrone0`
Any USB attached storage will be shared via NFS as /var/pidrone0-data

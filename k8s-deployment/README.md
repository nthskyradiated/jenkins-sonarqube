# Deploying Jenkins and Sonarqube on a Kubernetes Cluster

I'm currently running my Kubernetes cluster as a bare-metal deployment with local path provisioner from Rancher for persistent storage.

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

if you want to use local NFS shares (in the first control plane VM perhaps?) as persistent volumes for the cluster, follow the steps below:
* on controlplane / nfs server

  - `sudo apt install nfs-kernel-server`

  - `sudo mkdir -p /srv/nfs/kubedata`

  - `sudo chown nobody:nogroup /srv/nfs/kubedata`

  - `sudo nano /etc/exports`

  - `/srv/nfs/kubedata worker1(rw,sync,no_subtree_check) worker2(rw,sync,no_subtree_check)`

  - `sudo exportfs -ra`

  - `sudo systemctl start nfs-kernel-server`

  - `sudo systemctl enable nfs-kernel-server`


* on worker nodes / nfs clients

  - `sudo apt install nfs-common`

  - `sudo mkdir -p /mnt/nfs/kubedata`

  - `sudo mount <control-plane-ip>:/srv/nfs/kubedata /mnt/nfs/kubedata`

  - `df -h`

  - `sudo nano /etc/fstab`

  - `<control-plane-ip>:/srv/nfs/kubedata /mnt/nfs/kubedata nfs defaults 0 0`
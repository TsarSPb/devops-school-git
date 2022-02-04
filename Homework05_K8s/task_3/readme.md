# Class drills
## Deploying Minio
```
k apply -f pv.yaml
> persistentvolume/minio-deployment-pv created

k get pv
> NAME                  CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
> minio-deployment-pv   5Gi        RWO            Retain           Available                                   5s

k apply -f pvc.yaml
> persistentvolumeclaim/minio-deployment-claim created

k get pv
> NAME                  CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> minio-deployment-pv   5Gi        RWO            Retain           Bound    default/minio-deployment-claim                           94s

k get pvc
> NAME                     STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> minio-deployment-claim   Bound    minio-deployment-pv   5Gi        RWO                           79s

$ k get pv,pvc
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Recycle          Bound    default/minio-deployment-claim                           13m
> 
> NAME                                           STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound    minio-deployment-pv   5Gi        RWO                           17s
```

```
$ k apply -f deployment.yaml
> deployment.apps/minio created

$ k apply -f minio-nodeport.yaml
> service/minio-app created
```

Checking that data gets stored in the `pv`
```
docker@minikube:~$ ll /data
total 8
drwxr-xr-x 2 root root 4096 Dec 19 10:47 ./
drwxr-xr-x 1 root root 4096 Dec 19 10:47 ../
docker@minikube:~$ ll /data
total 12
drwxr-xr-x 3 root root 4096 Feb  3 09:56 ./
drwxr-xr-x 1 root root 4096 Dec 19 10:47 ../
drwxr-xr-x 3 root root 4096 Feb  3 09:56 pv0001/
docker@minikube:~$ ll /data/pv0001
total 12
drwxr-xr-x 3 root root 4096 Feb  3 09:56 ./
drwxr-xr-x 3 root root 4096 Feb  3 09:56 ../
drwxr-xr-x 6 root root 4096 Feb  3 09:56 .minio.sys/
```

Can now access the minio services web
```
minikube service --url minio-app
curl localhost:64939
```

## Accessing via Ingress rather than Service
But we know about `Ingress` now! Let's do it.  
```
$ k apply -f ingress.yaml 
ingress.networking.k8s.io/app-ingress created

$ k get ing
> NAME          CLASS    HOSTS   ADDRESS     PORTS   AGE
> app-ingress   <none>   *       localhost   80      14s

minikube tunnel
> ✅  Tunnel successfully started
> 
> 📌  NOTE: Please do not close this terminal as this process must stay alive for the tunnel to be accessible ...
> 
> ❗  Access to ports below 1024 may fail on Windows with OpenSSH clients older than v8.1. For more information, see: https://minikube.> sigs.k8s.io/docs/handbook/accessing/#access-to-ports-1024-on-windows-requires-root-permission
> 🏃  Starting tunnel for service app-ingress.

$ k get svc,ing
> NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
> service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP          98m
> service/minio-app    NodePort    10.96.188.61   <none>        9001:30008/TCP   2m57s
> service/nginx        ClusterIP   None           <none>        80/TCP           17m

NAME                                    CLASS    HOSTS   ADDRESS     PORTS   AGE
ingress.networking.k8s.io/app-ingress   <none>   *       localhost   80      111s

curl localhost
<!doctype html><html lang="en"><head><meta charset="utf-8"/><base href="/"/><meta content="width=device-width,initial-scale=1" name="viewport"/><meta content="#081C42"
.....
</svg></div></div></body></html>
```

## Deploying `StatefulSet`
```
$ k apply -f statefulset.yaml
statefulset.apps/minio-state created
service/minio-state created

$ k get pv,pvc,sts,po
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Retain           Bound    default/> minio-deployment-claim                         2m51s
> 
> NAME                                           STATUS    VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound     minio-deployment-pv   5Gi        RWO                           2m26s
> persistentvolumeclaim/minio-minio-state-0      Pending                                                   standard       79s
> 
> NAME                           READY   AGE
> statefulset.apps/minio-state   0/1     79s
> 
> NAME                         READY   STATUS    RESTARTS   AGE
> pod/minio-575d987896-wklkw   1/1     Running   0          106s
> pod/minio-state-0            0/1     Pending   0          79s
```

### Initial issue
PV claim for the state is `Pending` for some reason...
```
k describe persistentvolumeclaim/minio-minio-state-0
> Events:
>   Type    Reason                Age                   From                         Message
>   ----    ------                ----                  ----                         -------
>   Normal  ExternalProvisioning  13s (x15 over 3m15s)  persistentvolume-controller  waiting for a volume to be created, either by external provisioner "k8s.io/minikube-hostpath" or manually created by system administrator

k describe pod/minio-state-0
> Events:
>   Type     Reason            Age                   From               Message
>   ----     ------            ----                  ----               -------
>   Warning  FailedScheduling  41s (x10 over 9m58s)  default-scheduler  0/1 nodes are available: 1 pod has unbound immediate PersistentVolumeClaims.
```

Apparently, after adding `storageClassName: ""` to the manifest, and manually adding a new `PersistentVolume` (pv-ss.yaml) the issue was resolved.  
Not sure if it's my local issue or syntax change in newer K8s versions.  
```
  volumeClaimTemplates:
  - metadata:
      name: minio
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: ""
```
Generally, if the default `StorageClass` is defined in the cluster, the `storageClassName` is not required.  
There is one in `minikube`, but it still doesn't work
```
k get storageclass
> NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
> standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  4m23s

$ k get pv,pvc
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Recycle          Bound    default/minio-deployment-claim                           5m45s
> persistentvolume/minio-state           1Gi        RWO            Retain           Bound    default/minio-minio-state-0                              2s
> 
> NAME                                           STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound    minio-deployment-pv   5Gi        RWO                           5m36s
> persistentvolumeclaim/minio-minio-state-0      Bound    minio-state           1Gi        RWO                           3m40s
```

## Moving on
After applying the `statefilset.yaml` the `minio-minio-state-0` PVC is still pending, but now this is because there is just no available PV to bind to.
```
k apply -f statefulset.yaml
> statefulset.apps/minio-state created
> service/minio-state created

$ k get deploy,po,sts,pv,pvc
> NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/minio   1/1     1            1           4m44s
> NAME                         READY   STATUS    RESTARTS   AGE
> pod/minio-575d987896-rvn65   1/1     Running   0          4m44s
> pod/minio-state-0            0/1     Pending   0          23s
> NAME                           READY   AGE
> statefulset.apps/minio-state   0/1     23s
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Recycle          Bound    default/minio-deployment-claim                           18m
> NAME                                           STATUS    VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound     minio-deployment-pv   5Gi        RWO                           5m45s
> persistentvolumeclaim/minio-minio-state-0      Pending                                                                  23s
```
Creating a new PV and checking again (it can take a while to bound)
```
$ k apply -f ./pv-ss.yaml 
> persistentvolume/minio-state created

$ k get sts,pv,pvc
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Recycle          Bound    default/minio-deployment-claim                           22m
> persistentvolume/minio-state           1Gi        RWO            Retain           Bound    default/minio-minio-state-0                              30s
> 
> NAME                                           STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound    minio-deployment-pv   5Gi        RWO                           9m27s
> persistentvolumeclaim/minio-minio-state-0      Bound    minio-state           1Gi        RWO                           4m5s
```

# Homework
* We published minio "outside" using nodePort. Do the same but using ingress.
* Publish minio via ingress so that minio by ip_minikube and nginx returning hostname (previous job) by path ip_minikube/web are available at the same time.
* Create deploy with emptyDir save data to mountPoint emptyDir, delete pods, check data.
* Optional. Raise an nfs share on a remote machine. Create a pv using this share, create a pvc for it, create a deployment. Save data to the share, delete the deployment, delete the pv/pvc, check that the data is safe.

## Ingress
* We published minio "outside" using nodePort. Do the same but using ingress.

Have actually already implemented the `ingress` as a part of the class drills - see [Accessing via Ingress rather than Service ](#accessing-via-ingress-rather-than-service).  
Re-applying the manifest, just in case...
```
k apply -f ingress.yaml
> ingress.networking.k8s.io/app-ingress unchanged
```

Here is the current state of the cluster
```
$ k get deploy,po,svc,ing,pv,pvc
> NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/minio   1/1     1            1           26m
> 
> NAME                         READY   STATUS    RESTARTS   AGE
> pod/minio-575d987896-chdrt   1/1     Running   0          26m
> pod/minio-state-0            1/1     Running   0          26m
> 
> NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
> service/kubernetes    ClusterIP   10.96.0.1      <none>        443/TCP          3h7m
> service/minio-app     NodePort    10.100.36.11   <none>        9001:30008/TCP   26m
> service/minio-state   ClusterIP   None           <none>        9000/TCP         26m
> 
> NAME                                    CLASS    HOSTS   ADDRESS     PORTS   AGE
> ingress.networking.k8s.io/app-ingress   <none>   *       localhost   80      26m
> 
> NAME                                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                            STORAGECLASS   REASON   AGE
> persistentvolume/minio-deployment-pv   5Gi        RWO            Recycle          Bound    default/minio-deployment-claim                           26m
> persistentvolume/minio-state           1Gi        RWO            Recycle          Bound    default/minio-minio-state-0                              26m
> 
> NAME                                           STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS   AGE
> persistentvolumeclaim/minio-deployment-claim   Bound    minio-deployment-pv   5Gi        RWO                           26m
> persistentvolumeclaim/minio-minio-state-0      Bound    minio-state           1Gi        RWO                           26m

minikube tunnel
> ✅  Tunnel successfully started
> 
> 📌  NOTE: Please do not close this terminal as this process must stay alive for the tunnel to be accessible ...
> 
> ❗  Access to ports below 1024 may fail on Windows with OpenSSH clients older than v8.1. For more information, see: https://minikube.> sigs.k8s.io/docs/handbook/accessing/#access-to-ports-1024-on-windows-requires-root-permission
> ❗  Access to ports below 1024 may fail on Windows with OpenSSH clients older than v8.1. For more information, see: https://minikube.> sigs.k8s.io/docs/handbook/accessing/#access-to-ports-1024-on-windows-requires-root-permission
> 🏃  Starting tunnel for service app-ingress.
```

The `ingress` for the new app is configured to listen on the `/`  (as per `ingress.yaml`)
```
$ curl localhost
> <!doctype html><html lang="en"><head><meta charset="utf-8"/><base href="/"/><meta content="width=device-width,initial-scale=1" name="viewport"/><meta content="#081C42" media="(prefers-color-scheme: light)" name="theme-color"/><meta content="#081C42" media="(prefers-color-scheme: dark)" name="theme-color"/><meta content="MinIO Console" name="description"/><link href="./styles/root-styles.css" rel="stylesheet"/><link href="./apple-icon-180x180.png" rel="apple-touch-icon" sizes="180x180"/><link href="./favicon-32x32.png" rel="icon" sizes="32x32" type="image/png"/><link href="./favicon-96x96.png" rel="icon" sizes="96x96" type="image/png"/><link href="./favicon-16x16.png" rel="icon" sizes="16x16" type="image/png"/><link href="./manifest.json" rel="manifest"/><link color="#3a4e54" href="./safari-pinned-tab.svg" rel="mask-icon"/><title>MinIO Console</title><script defer="defer" src="./static/js/main.c2f8fc5a.js"></script><link href="./static/css/main.c4c1effe.css" rel="stylesheet"></head><body><noscript>You need to enable JavaScript to run this app.</noscript><div id="root"><div id="loader-block"><svg class="loader-svg-container" viewBox="22 22 44 44"><circle class="loader-style MuiCircularProgress-circle MuiCircularProgress-circleIndeterminate" cx="44" cy="44" fill="none" r="20.2" stroke-width="3.6"></circle></svg></div></div></body></html>
```

## Ingress paths
* Publish minio via ingress so that minio by ip_minikube and nginx returning hostname (previous job) by path ip_minikube/web are available at the same time.

Deploying the app from `task2`
```
k create ns prod-web
> namespace/prod-web created
$ k apply -n prod-web -f old_app/.
> deployment.apps/web created
> ingress.networking.k8s.io/ingress-web created
> configmap/nginx-configmap created
> service/web-np created

k get -n prod-web deploy,po,svc,ing
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   1/3     3            1           14s
> 
> NAME                      READY   STATUS              RESTARTS   AGE
> pod/web-78bf47f5f-4294x   0/1     ContainerCreating   0          14s
> pod/web-78bf47f5f-kxjmq   0/1     ContainerCreating   0          14s
> pod/web-78bf47f5f-rk2js   1/1     Running             0          14s
> 
> NAME             TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
> service/web-np   NodePort   10.109.47.147   <none>        80:30828/TCP   14s
> 
> NAME                                    CLASS    HOSTS   ADDRESS     PORTS   AGE
> ingress.networking.k8s.io/ingress-web   <none>   *       localhost   80      14s
```

The `ingress` for the old app is configured to listen on the `/web` path
```
$ while true; do curl localhost/web; sleep 1; done;
web-5584c6c5c6-8lvrc
web-5584c6c5c6-8lvrc
web-5584c6c5c6-xzx8x
web-5584c6c5c6-8lvrc
web-5584c6c5c6-xzx8x
web-5584c6c5c6-8pp5v
```
The `ingress` for the new app is configured to listen on the `/` path
```
$ curl localhost
> <!doctype html><html lang="en"><head><meta charset="utf-8"/><base href="/"/><meta content="width=device-width,initial-scale=1" name="viewport"/><meta content="#081C42" media="(prefers-color-scheme: light)" name="theme-color"/><meta content="#081C42" media="(prefers-color-scheme: dark)" name="theme-color"/><meta content="MinIO Console" name="description"/><link href="./styles/root-styles.css" rel="stylesheet"/><link href="./apple-icon-180x180.png" rel="apple-touch-icon" sizes="180x180"/><link href="./favicon-32x32.png" rel="icon" sizes="32x32" type="image/png"/><link href="./favicon-96x96.png" rel="icon" sizes="96x96" type="image/png"/><link href="./favicon-16x16.png" rel="icon" sizes="16x16" type="image/png"/><link href="./manifest.json" rel="manifest"/><link color="#3a4e54" href="./safari-pinned-tab.svg" rel="mask-icon"/><title>MinIO Console</title><script defer="defer" src="./static/js/main.c2f8fc5a.js"></script><link href="./static/css/main.c4c1effe.css" rel="stylesheet"></head><body><noscript>You need to enable JavaScript to run this app.</noscript><div id="root"><div id="loader-block"><svg class="loader-svg-container" viewBox="22 22 44 44"><circle class="loader-style MuiCircularProgress-circle MuiCircularProgress-circleIndeterminate" cx="44" cy="44" fill="none" r="20.2" stroke-width="3.6"></circle></svg></div></div></body></html>
```

## emptyDir mountPoint
* Create deploy with emptyDir save data to mountPoint emptyDir, delete pods, check data.

Here is the excerpt from the `deploy-emptyDir.yaml`
```
        volumeMounts:
        - name: data
          mountPath: /files
      volumes:
      - name: data
        emptyDir: {}
```

Creating the `Deployment` and adding a sample file to the mounted folder.
```
k apply -f mountPoint/deploy-emptyDir.yaml 
> deployment.apps/emptydir-deployment created

k get deploy,po -l app=emptydir-deployment
> NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/emptydir-deployment   0/1     1            0           9s
> 
> NAME                                      READY   STATUS              RESTARTS   AGE
> pod/emptydir-deployment-cbc987bbb-jvzgr   0/1     ContainerCreating   0          9s

k exec -it emptydir-deployment-cbc987bbb-jvzgr -- bash
root@emptydir-deployment-cbc987bbb-jvzgr:/# touch /files/sample.txt
root@emptydir-deployment-cbc987bbb-jvzgr:/# ls /files
sample.txt
root@emptydir-deployment-cbc987bbb-jvzgr:/# mount | grep files
/dev/sdc on /files type ext4 (rw,relatime,discard,errors=remount-ro,data=ordered)
```
### Killing the pod to force its restart
```
docker@minikube:~$ docker ps | grep emptydir
> 7d00a6656563   nginx                  "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes
docker kill 7d00a6656563
7d00a6656563
$ k get deploy,po -l app=emptydir-deployment
> NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/emptydir-deployment   1/1     1            1           3m32s
> 
> NAME                                      READY   STATUS    RESTARTS      AGE
> pod/emptydir-deployment-cbc987bbb-jvzgr   1/1     Running   1 (15s ago)   3m32s
```
Getting back into the pod - the file is still there.  
The pod was just restarted, not recreated, so the same volume gets attached to it.  
```
k exec -it emptydir-deployment-cbc987bbb-jvzgr -- bash
root@emptydir-deployment-cbc987bbb-jvzgr:/# ls /files
> sample.txt
```
### Deleting the pod
```
$ k delete po emptydir-deployment-cbc987bbb-jvzgr
pod "emptydir-deployment-cbc987bbb-jvzgr" deleted
```
New one gets automatically created, but the file isn't there anymore
``` 
$ k get deploy,po -l app=emptydir-deployment
> NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/emptydir-deployment   1/1     1            1           5m58s
> 
> NAME                                      READY   STATUS    RESTARTS   AGE
> pod/emptydir-deployment-cbc987bbb-thftg   1/1     Running   0          18s

$ k exec -it emptydir-deployment-cbc987bbb-thftg -- bash
> root@emptydir-deployment-cbc987bbb-thftg:/# ls /files
> root@emptydir-deployment-cbc987bbb-thftg:/# 
```

All the data is lost since an `emptyDir` volume only exists as long as the Pod was running.
When a Pod is recreated or moved from a node for any reason, the data in the emptyDir is deleted permanently ([source](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)).

## NFS share
* Optional. Raise an nfs share on a remote machine. Create a pv using this share, create a pvc for it, create a deployment. Save data to the share, delete the deployment, delete the pv/pvc, check that the data is safe.

This one is optional will probably do it later if time permits

# Quick recap / snippets
## Creating
```
k apply -f pv.yaml
k apply -f pvc.yaml
k apply -f deployment.yaml
k apply -f minio-nodeport.yaml
k apply -f ingress.yaml
k apply -f pv-ss.yaml
k apply -f statefulset.yaml
k get deploy,po,svc,ing,pv,pvc

k apply -n prod-web -f old_app/.
k get -n prod-web deploy,po,svc,ing

k apply -f mountPoint/deploy-emptyDir.yaml
k get deploy,po -l app=emptydir-deployment
```

## Deleting
```
k delete ns prod-web
k delete -f mountPoint/. 
k delete -f deployment.yaml
k delete -f minio-nodeport.yaml
k delete -f ingress.yaml
k delete -f statefulset.yaml
k delete pvc minio-minio-state-0
k delete -f pv-ss.yaml
k delete -f pvc.yaml
k delete -f pv.yaml
```

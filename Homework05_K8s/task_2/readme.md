# General info
The first part in this readme contains some test and exploratory / curiosity commands.  
The `Homework` itself is the last section, here is the link right to it: [the Homework ](#homework)

# Class drills
## Creating secret, cm and a pod
```
kubectl create secret generic connection-string --from-literal=DATABASE_URL=postgres://connect --dry-run=client -o yaml > secret.yaml
kubectl create configmap user --from-literal=firstname=firstname --from-literal=lastname=lastname --dry-run=client -o yaml > cm.yaml
kubectl apply -f secret.yaml
kubectl apply -f cm.yaml
kubectl apply -f pod.yaml
```
ConfigMap name is 'user'
```
metadata:
  creationTimestamp: null
  name: user
k get cm
> NAME               DATA   AGE
> kube-root-ca.crt   1      40d
> user               2      7m59s
```
Two ways to reference `secret` / `ConfigMap` from the `Pod` - entire file or only selected entities. Env. variable name can be set / changed in the latter case.
```
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: connection-string
          key: DATABASE_URL
    envFrom:
      - configMapRef:
          name: user
```
Changing key name in the `secret` like this
```
      valueFrom:
        secretKeyRef:
          name: connection-string
          key: DATABASE_URL222
```
will result in pod failing to start:
```
  Warning  Failed     8s (x3 over 38s)   kubelet            Error: couldn't find key DATABASE_URL in Secret default/connection-string
```
Decoding the secret
```
k get secret connection-string -o yaml | grep "DATABASE_URL:" | awk '{print $2}' | base64 -d
> postgres://connect
k get secret connection-string -o jsonpath='{.data.DATABASE_URL}' |
 base64 -d
> postgres://connect
```
Getting inside the container and printing its env outputs, among others, the `firstname` and `lastname` env vars from the ConfigMap and `DATABASE_URL` from the secret
```
tsar@DESKTOP-80THIFC:task_2$ kubectl exec -it nginx -- bash
root@nginx:/# printenv
> ...
> lastname=lastname
> firstname=firstname
> DATABASE_URL=postgres://connect
```

## Adding nginx deploy
```
kubectl apply -f nginx-configmap.yaml
kubectl apply -f deployment.yaml

tsar@DESKTOP-80THIFC:task_2$ k get deploy,po,cm,secret
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   3/3     3            3           47s
> 
> NAME                       READY   STATUS    RESTARTS   AGE
> pod/nginx                  1/1     Running   0          7m1s
> pod/web-5584c6c5c6-bkmhz   1/1     Running   0          47s
> pod/web-5584c6c5c6-j52tl   1/1     Running   0          47s
> pod/web-5584c6c5c6-ssl8f   1/1     Running   0          47s
> 
> NAME                         DATA   AGE
> configmap/kube-root-ca.crt   1      40d
> configmap/nginx-configmap    1      48s
> configmap/user               2      30m
> 
> NAME                         TYPE                                  DATA   > AGE
> secret/connection-string     Opaque                                1      > 30m
> secret/default-token-qtjrj   kubernetes.io/service-account-token   3      40d

tsar@DESKTOP-80THIFC:task_2$ k get cm nginx-configmap -o yaml
apiVersion: v1
data:
  default.conf: |-
    server {
        listen 80 default_server;
        server_name _;
        default_type text/plain;

        location / {
            return 200 '$hostname\n';
        }
    }
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"default.conf":"server {\n    listen 80 default_server;\n    server_name _;\n    default_type text/plain;\n\n    location / {\n        return 200 '$hostname\\n';\n    }\n}"},"kind":"ConfigMap","metadata":{"annotations":{},"creationTimestamp":null,"name":"nginx-configmap","namespace":"default"}}
  creationTimestamp: "2022-01-31T12:00:25Z"
  name: nginx-configmap
  namespace: default
  resourceVersion: "802"
  uid: f050bf02-35ce-4240-a21c-d0e107ca22bf
```

## Connecting to pods
### Via Pod IP
```
tsar@DESKTOP-80THIFC:task_2$ k get po -o wide
> NAME                   READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
> nginx                  1/1     Running   0          5m30s   172.17.0.2   minikube   <none>           <none>
> web-5584c6c5c6-hddgw   1/1     Running   0          4m9s    172.17.0.9   minikube   <none>           <none>
> web-5584c6c5c6-kjwx4   1/1     Running   0          4m9s    172.17.0.7   minikube   <none>           <none>
> web-5584c6c5c6-tnfr5   1/1     Running   0          4m9s    172.17.0.8   minikube   <none>           <none>
```

* Try connect to pod with curl (curl pod_ip_address). What happens?
* From you PC
* From minikube (minikube ssh)
* From another pod (kubectl exec -it $(kubectl get pod |awk '{print $1}'|grep web-|head -n1) bash)

curl doesn't work from the host, but works from the minikube node and other pods
```
tsar@DESKTOP-80THIFC:task_2$ curl 172.17.0.9
curl: (28) Failed to connect to 172.17.0.9 port 80: Connection timed out

docker@minikube:~$ curl 172.17.0.9
web-5584c6c5c6-hddgw
docker@minikube:~$ curl 172.17.0.7
web-5584c6c5c6-kjwx4

root@web-5584c6c5c6-hddgw:/# curl 172.17.0.9
web-5584c6c5c6-hddgw
root@web-5584c6c5c6-hddgw:/# curl 172.17.0.7
web-5584c6c5c6-kjwx4
```
### Via Service ClusterIP
```
tsar@DESKTOP-80THIFC:task_2$ k expose deployment/web --type=ClusterIP --dry-run=client -o yaml > service_template.yaml
tsar@DESKTOP-80THIFC:task_2$ k apply -f service_template.yaml
> service/web created
tsar@DESKTOP-80THIFC:task_2$ k get svc
> NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
> kubernetes   ClusterIP   10.96.0.1     <none>        443/TCP   28m
> web          ClusterIP   10.97.90.37   <none>        80/TCP    3s
```

* Try connect to service (curl service_ip_address). What happens?
* From you PC
* From minikube (minikube ssh) (run the command several times)
* From another pod (kubectl exec -it $(kubectl get pod |awk '{print $1}'|grep web-|head -n1) bash) (run the command several times)

curl still doesn't work from the host, but works from the minikube node and other pods
It works differently now, though - service returns different hosts
```
tsar@DESKTOP-80THIFC:task_2$ curl 172.17.0.9
curl: (28) Failed to connect to 172.17.0.9 port 80: Connection timed out

docker@minikube:~$ curl 10.97.90.37
web-5584c6c5c6-hddgw
docker@minikube:~$ curl 10.97.90.37
web-5584c6c5c6-tnfr5

root@web-5584c6c5c6-hddgw:/# curl 10.97.90.37
web-5584c6c5c6-kjwx4
root@web-5584c6c5c6-hddgw:/# curl 10.97.90.37
web-5584c6c5c6-tnfr5
```

### Via Service NodePort
```
kubectl apply -f service-nodeport.yaml
> service/web-np created
tsar@DESKTOP-80THIFC:task_2$ kubectl get service
> NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
> kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        49m
> web          ClusterIP   10.97.90.37      <none>        80/TCP         21m
> web-np       NodePort    10.103.138.236   <none>        80:30755/TCP   0s
minikube ip
> 192.168.49.2
```

Still works from minikube host and other pods and doesn't work from the host.
```
tsar@DESKTOP-80THIFC:task_2$ curl 192.168.49.2:30755
curl: (28) Failed to connect to 192.168.49.2 port 30755: Connection timed out

docker@minikube:~$ curl 192.168.49.2:30755
web-5584c6c5c6-hddgw
docker@minikube:~$ curl 192.168.49.2:30755
web-5584c6c5c6-kjwx4

root@web-5584c6c5c6-tnfr5:/# curl 192.168.49.2:30755
web-5584c6c5c6-hddgw
root@web-5584c6c5c6-tnfr5:/# curl 192.168.49.2:30755
web-5584c6c5c6-kjwx4
```

### Headless Service
```
kubectl apply -f service-headless.yaml
tsar@DESKTOP-80THIFC:task_2$ kubectl exec -it web-5584c6c5c6-hddgw -- bash
root@web-5584c6c5c6-hddgw:/# cat /etc/resolv.conf
> nameserver 10.96.0.10
> search default.svc.cluster.local svc.cluster.local cluster.local
> options ndots:5
tsar@DESKTOP-80THIFC:task_2$ kubectl get ep
> NAME           ENDPOINTS                                   AGE
> kubernetes     192.168.49.2:8443                           79m
> web            172.17.0.7:80,172.17.0.8:80,172.17.0.9:80   50m
> web-headless   172.17.0.7:80,172.17.0.8:80,172.17.0.9:80   23m
> web-np         172.17.0.7:80,172.17.0.8:80,172.17.0.9:80   29m
```
* Compare the IP address of the DNS server in the pod and the DNS service of the Kubernetes cluster.
* Compare headless and clusterip
* Inside the pod run nslookup to normal clusterip and headless. Compare the results.

```
kubectl -n default create deploy busybox --image=busybox -- /bin/sh -c "while true; do sleep 30; done;"
kubectl -n default create deploy busybox-curl --image=zemond/busybox-curl -- /bin/sh -c "wh
ile true; do sleep 30; done;"
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- sh

tsar@DESKTOP-80THIFC:task_2$ k get svc,po -o wide
> NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE     SELECTOR
> service/kubernetes     ClusterIP   10.96.0.1        <none>        443/TCP        3h56m   <none>
> service/web            ClusterIP   10.97.90.37      <none>        80/TCP         3h27m   app=web
> service/web-headless   ClusterIP   None             <none>        80/TCP         179m    app=web
> service/web-np         NodePort    10.103.138.236   <none>        80:30755/TCP   3h6m    app=web

> NAME                                READY   STATUS    RESTARTS   AGE     IP            NODE    
> pod/busybox-596d5d8fd6-dxplx        1/1     Running   0          30m     172.17.0.10   minikube
> pod/busybox-curl-55bf5999d7-zkcfm   1/1     Running   0          28m     172.17.0.11   minikube
> pod/nginx                           1/1     Running   0          3h54m   172.17.0.2    minikube
> pod/web-5584c6c5c6-hddgw            1/1     Running   0          3h52m   172.17.0.9    minikube
> pod/web-5584c6c5c6-kjwx4            1/1     Running   0          3h52m   172.17.0.7    minikube
> pod/web-5584c6c5c6-tnfr5            1/1     Running   0          3h52m   172.17.0.8    minikube

tsar@DESKTOP-80THIFC:task_2$ k exec -it busybox-curl-55bf5999d7-zkcfm -- sh
/home # curl web
> web-5584c6c5c6-kjwx4
/home # nslookup web
> Server:    10.96.0.10
> Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
> Name:      web
> Address 1: 10.97.90.37 web.default.svc.cluster.local

/home # nslookup web-np
> Server:    10.96.0.10
> Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
> Name:      web-np
> Address 1: 10.103.138.236 web-np.default.svc.cluster.local

/home # nslookup web-headless
> Server:    10.96.0.10
> Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
> Name:      web-headless
> Address 1: 172.17.0.8 172-17-0-8.web-np.default.svc.cluster.local
> Address 2: 172.17.0.7 172-17-0-7.web.default.svc.cluster.local
> Address 3: 172.17.0.9 172-17-0-9.web.default.svc.cluster.local

/home # cat /etc/resolv.conf
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

So apparently 
`nslookup web`          returns service   ClusterIP
`nslookup web-np`       returns service's ClusterIP
`nslookup web-headless` returns a list of IPs of the pods

### Ingress
```
minikube addons enable ingress
minikube addons list
kubectl get pods -n ingress-nginx
kubectl get pod $(kubectl get pod -n ingress-nginx|grep ingress-nginx-controller|awk '{print $1}') -n ingress-nginx -o yaml
minikube tunnel
curl localhost
> web-5584c6c5c6-hddgw
curl localhost
> web-5584c6c5c6-tnfr5
```

# Homework
* In Minikube in namespace kube-system, there are many different pods running. Your task is to figure out who creates them, and who makes sure they are running (restores them after deletion).

* Implement Canary deployment of an application via Ingress. Traffic to canary deployment should be redirected if you add "canary:always" in the header, otherwise it should go to regular deployment.
Set to redirect a percentage of traffic to canary deployment.

[Assignment 1 kube-system Namespace](#part-1-kube-system-namespace)  
[Assignment 2 Canary Ingress](#part-2-canary-ingress)  

## Part 1 kube-system namespace
* In Minikube in namespace kube-system, there are many different pods running. Your task is to figure out who creates them, and who makes sure they are running (restores them after deletion).

### General thoughts
Not sure I understand the question correctly, but here are my thoughts on it...

Apparently, in `Minikube` most pods in the `kube-system` namespace are created as static pods and the manifests for them are stored in `/etc/kubernetes/manifests` and the pods are managed the `kubelet` daemon on a specific node, `control plane`, in this case.  

[Here is the link to the reference doc](https://kubernetes.io/docs/reference/setup-tools/kubeadm/implementation-details/) and [here is another one](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/).

`coredns` is an addon and Minikube has an addon manager that periodically verifies the configuration state of any installed addons, and Kube-DNS is one of those addons [source](https://coredns.io/2017/04/28/coredns-for-minikube/).

`kube-proxy` in `Minikube` is deployed as a `daemonset` but I'm not sure ~~who watches the watchmen~~ who controls the DaemonSet itself.  

```
docker@minikube:~$ ll /etc/kubernetes/manifests/
total 28
drwxr-xr-x 1 root root 4096 Feb  2 16:44 ./
drwxr-xr-x 1 root root 4096 Feb  2 16:44 ../
-rw------- 1 root root 2309 Feb  2 16:44 etcd.yaml
-rw------- 1 root root 4071 Feb  2 16:44 kube-apiserver.yaml
-rw------- 1 root root 3405 Feb  2 16:44 kube-controller-manager.yaml
-rw------- 1 root root 1451 Feb  2 16:44 kube-scheduler.yaml
```

### Out of the box state of the kube-system Namespace
```
$ kubectl get deploy,rs,ds,po,svc,ep,sa,secret,cm -n kube-system
> NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/coredns   1/1     1            1           14h
> 
> NAME                                 DESIRED   CURRENT   READY   AGE
> replicaset.apps/coredns-78fcd69978   1         1         1       14h
> 
> NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
> daemonset.apps/kube-proxy   1         1         1       1            1           kubernetes.io/os=linux   14h
> 
> NAME                                   READY   STATUS    RESTARTS   AGE
> pod/coredns-78fcd69978-mj4z7           1/1     Running   0          13h
> pod/etcd-minikube                      1/1     Running   17         13h
> pod/kube-apiserver-minikube            1/1     Running   17         13h
> pod/kube-controller-manager-minikube   1/1     Running   17         13h
> pod/kube-proxy-hnndh                   1/1     Running   0          13h
> pod/kube-scheduler-minikube            1/1     Running   17         13h
> 
> NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
> service/kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   14h
> 
> NAME                                 ENDPOINTS                                     AGE
> endpoints/k8s.io-minikube-hostpath   <none>                                        14h
> endpoints/kube-dns                   172.17.0.2:53,172.17.0.2:53,172.17.0.2:9153   14h
> 
> NAME                                                SECRETS   AGE
> serviceaccount/attachdetach-controller              1         14h
> serviceaccount/bootstrap-signer                     1         14h
> serviceaccount/certificate-controller               1         14h
> serviceaccount/clusterrole-aggregation-controller   1         14h
> serviceaccount/coredns                              1         14h
> serviceaccount/cronjob-controller                   1         14h
> serviceaccount/daemon-set-controller                1         14h
> serviceaccount/default                              1         14h
> serviceaccount/deployment-controller                1         14h
> serviceaccount/disruption-controller                1         14h
> serviceaccount/endpoint-controller                  1         14h
> serviceaccount/endpointslice-controller             1         14h
> serviceaccount/endpointslicemirroring-controller    1         14h
> serviceaccount/ephemeral-volume-controller          1         14h
> serviceaccount/expand-controller                    1         14h
> serviceaccount/generic-garbage-collector            1         14h
> serviceaccount/horizontal-pod-autoscaler            1         14h
> serviceaccount/job-controller                       1         14h
> serviceaccount/kube-proxy                           1         14h
> serviceaccount/namespace-controller                 1         14h
> serviceaccount/node-controller                      1         14h
> serviceaccount/persistent-volume-binder             1         14h
> serviceaccount/pod-garbage-collector                1         14h
> serviceaccount/pv-protection-controller             1         14h
> serviceaccount/pvc-protection-controller            1         14h
> serviceaccount/replicaset-controller                1         14h
> serviceaccount/replication-controller               1         14h
> serviceaccount/resourcequota-controller             1         14h
> serviceaccount/root-ca-cert-publisher               1         14h
> serviceaccount/service-account-controller           1         14h
> serviceaccount/service-controller                   1         14h
> serviceaccount/statefulset-controller               1         14h
> serviceaccount/storage-provisioner                  1         14h
> serviceaccount/token-cleaner                        1         14h
> serviceaccount/ttl-after-finished-controller        1         14h
> serviceaccount/ttl-controller                       1         14h
> 
> NAME                                                    TYPE                                  DATA   AGE
> secret/attachdetach-controller-token-j8x7h              kubernetes.io/service-account-token   3      14h
> secret/bootstrap-signer-token-st4j9                     kubernetes.io/service-account-token   3      14h
> secret/bootstrap-token-q1fjwy                           bootstrap.kubernetes.io/token         6      14h
> secret/certificate-controller-token-rzt4v               kubernetes.io/service-account-token   3      14h
> secret/clusterrole-aggregation-controller-token-zjtdx   kubernetes.io/service-account-token   3      14h
> secret/coredns-token-sjsxm                              kubernetes.io/service-account-token   3      14h
> secret/cronjob-controller-token-cd8mf                   kubernetes.io/service-account-token   3      14h
> secret/daemon-set-controller-token-zjz9t                kubernetes.io/service-account-token   3      14h
> secret/default-token-7tpvl                              kubernetes.io/service-account-token   3      14h
> secret/deployment-controller-token-54w92                kubernetes.io/service-account-token   3      14h
> secret/disruption-controller-token-zxxzp                kubernetes.io/service-account-token   3      14h
> secret/endpoint-controller-token-rvxxd                  kubernetes.io/service-account-token   3      14h
> secret/endpointslice-controller-token-md9b4             kubernetes.io/service-account-token   3      14h
> secret/endpointslicemirroring-controller-token-ngxrb    kubernetes.io/service-account-token   3      14h
> secret/ephemeral-volume-controller-token-c8brw          kubernetes.io/service-account-token   3      14h
> secret/expand-controller-token-6crr8                    kubernetes.io/service-account-token   3      14h
> secret/generic-garbage-collector-token-6ww79            kubernetes.io/service-account-token   3      14h
> secret/horizontal-pod-autoscaler-token-jlsck            kubernetes.io/service-account-token   3      14h
> secret/job-controller-token-n68hb                       kubernetes.io/service-account-token   3      14h
> secret/kube-proxy-token-2hg8k                           kubernetes.io/service-account-token   3      14h
> secret/namespace-controller-token-rrxr9                 kubernetes.io/service-account-token   3      14h
> secret/node-controller-token-z8nsb                      kubernetes.io/service-account-token   3      14h
> secret/persistent-volume-binder-token-4fpcs             kubernetes.io/service-account-token   3      14h
> secret/pod-garbage-collector-token-ql4cs                kubernetes.io/service-account-token   3      14h
> secret/pv-protection-controller-token-pd42f             kubernetes.io/service-account-token   3      14h
> secret/pvc-protection-controller-token-zl9sz            kubernetes.io/service-account-token   3      14h
> secret/replicaset-controller-token-kdtvv                kubernetes.io/service-account-token   3      14h
> secret/replication-controller-token-2txl7               kubernetes.io/service-account-token   3      14h
> secret/resourcequota-controller-token-8qxkr             kubernetes.io/service-account-token   3      14h
> secret/root-ca-cert-publisher-token-w8v4f               kubernetes.io/service-account-token   3      14h
> secret/service-account-controller-token-vfc8q           kubernetes.io/service-account-token   3      14h
> secret/service-controller-token-rd2cw                   kubernetes.io/service-account-token   3      14h
> secret/statefulset-controller-token-kdzxl               kubernetes.io/service-account-token   3      14h
> secret/storage-provisioner-token-8q7wj                  kubernetes.io/service-account-token   3      14h
> secret/token-cleaner-token-lltz4                        kubernetes.io/service-account-token   3      14h
> secret/ttl-after-finished-controller-token-psljd        kubernetes.io/service-account-token   3      14h
> secret/ttl-controller-token-gjx4k                       kubernetes.io/service-account-token   3      14h
> 
> NAME                                           DATA   AGE
> configmap/coredns                              1      14h
> configmap/extension-apiserver-authentication   6      14h
> configmap/kube-proxy                           2      14h
> configmap/kube-root-ca.crt                     1      14h
> configmap/kubeadm-config                       1      14h
> configmap/kubelet-config-1.22                  1      14h
```

## Part 2 Canary Ingress
* Implement Canary deployment of an application via Ingress. Traffic to canary deployment should be redirected if you add "canary:always" in the header, otherwise it should go to regular deployment.
Set to redirect a percentage of traffic to canary deployment.

> All the manifests and the Dockerfile for this task are located in the `./canary` folder

### Building Docker images for app v1.0 and 2.0
```
PROJECT_ID=k8s-canary
app_version=1.0
docker build --build-arg version=$app_version -t tsarspb/$PROJECT_ID:$app_version .
docker tag tsarspb/$PROJECT_ID:$app_version tsarspb/$PROJECT_ID:latest
docker images "tsarspb/*"
> REPOSITORY           TAG       IMAGE ID       CREATED         SIZE
> tsarspb/k8s-canary   1.0       43584252353d   9 minutes ago   11.4MB
> tsarspb/k8s-canary   latest    43584252353d   9 minutes ago   11.4MB
docker login -u tsarspb
docker push tsarspb/$PROJECT_ID:latest
docker push tsarspb/$PROJECT_ID:$app_version

app_version=2.0
docker build --build-arg version=$app_version -t tsarspb/$PROJECT_ID:$app_version .

$ docker tag tsarspb/$PROJECT_ID:$app_version tsarspb/$PROJECT_ID:latest
$ docker images "tsarspb/*"
> REPOSITORY           TAG       IMAGE ID       CREATED          SIZE
> tsarspb/k8s-canary   2.0       c7df76fd622b   47 seconds ago   11.4MB
> tsarspb/k8s-canary   latest    c7df76fd622b   47 seconds ago   11.4MB
> tsarspb/k8s-canary   1.0       43584252353d   42 minutes ago   11.4MB

docker push tsarspb/$PROJECT_ID:latest
docker push tsarspb/$PROJECT_ID:$app_version
```

### Deploying "Production" v1.0 and "Canary" v2.0 versions of the app
```
kubectl create ns prod
kubectl apply -f ./deploy.yaml -n prod
kubectl apply -f ./deploy-canary.yaml -n prod

$ kubectl get po -n prod
> NAME                                  READY   STATUS    RESTARTS   AGE
> kubeapp-canary-56476554c4-wwgjw       1/1     Running   0          27s
> kubeapp-production-6556ddf7b8-kk55v   1/1     Running   0          4m20s
> kubeapp-production-6556ddf7b8-kls57   1/1     Running   0          4m20s
> kubeapp-production-6556ddf7b8-m2cqm   1/1     Running   0          4m20s
```

### Deploying Production and Canary services
```
$ kubectl apply -f ./service-np.yaml -n prod
> service/kubeapp-production-service created
$ kubectl apply -f ./service-np-canary.yaml -n prod
> service/kubeapp-canary-service created

$ kubectl get svc -n prod
> NAME                         TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
> kubeapp-canary-service       NodePort   10.102.24.194    <none>        81:31022/TCP   6s
> kubeapp-production-service   NodePort   10.104.220.185   <none>        81:32624/TCP   14s
``` 

### Deploying ingress
```
$ kubectl apply -f ./ingress.yaml -n prod
> ingress.networking.k8s.io/app-ingress created

$ kubectl apply -f ./ingress-canary.yaml -n prod
> ingress.networking.k8s.io/app-ingress-canary created

$ kubectl get svc,ing -n prod
> NAME                                 TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
> service/kubeapp-canary-service       NodePort   10.102.24.194    <none>        81:31022/TCP   10m
> service/kubeapp-production-service   NodePort   10.104.220.185   <none>        81:32624/TCP   10m
> 
> NAME                                           CLASS    HOSTS   ADDRESS     PORTS   AGE
> ingress.networking.k8s.io/app-ingress          <none>   *       localhost   80      2m3s
> ingress.networking.k8s.io/app-ingress-canary   <none>   *       localhost   80      115s
```

### Testing the configuration
> I've deviated a bit from the strict definition of the task and added `canary-weight` annotation just for the sake of experiment / as as part of exploration, so my ingress never always returns some % of "canary" version.

Here is the excerpt from the app-ingress-canary
```
metadata:
  name: app-ingress-canary
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
    nginx.ingress.kubernetes.io/canary-by-header: "canary"
```
We shoud be routed to the canary v2.0 in ~10% requests when the "canary" header is not specified or its value isn't "always" (in this case ingress falls back to routing based on weight) or in 100% requests when the value of the "canary" header is set to "always".  


#### Testing with no header specified
Ingress falls back to routing based on weight and should route to the canary v2.0 in ~10% requests
```
minikube tunnel
$ while true; do curl localhost; echo ; sleep 1; done;
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 2.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 2.0 of your application is running on Kubernetes.
```

#### Testing with "canary:always" header
Ingress routes all the requests to the canary v2.0
```
$ while true; do curl -H "canary:always" localhost; echo ; sleep 1; done;
Congratulations! Version 2.0 of your application is running on Kubernetes.
Congratulations! Version 2.0 of your application is running on Kubernetes.
Congratulations! Version 2.0 of your application is running on Kubernetes.
Congratulations! Version 2.0 of your application is running on Kubernetes.
Congratulations! Version 2.0 of your application is running on Kubernetes.
```

#### Testing with "canary" header set to a value other than "always"
Ingress falls back to routing based on weight and shoud route to the canary v2.0 in ~10% requests
```
$ while true; do curl -H "canary:somev" localhost; echo ; sleep 1; done;
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 2.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
> Congratulations! Version 2.0 of your application is running on Kubernetes.
> Congratulations! Version 1.0 of your application is running on Kubernetes.
```

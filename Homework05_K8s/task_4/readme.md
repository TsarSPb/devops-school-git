# General info
The first part in this readme contains some test and exploratory / curiosity commands.  
The `Homework` itself down below, after the `Class drills` section, here is the link right to it: [the Homework ](#homework)

# Reference doc
https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
https://kubernetes.io/docs/reference/access-authn-authz/authorization/

# Class drills
## Check what I can do
```
$ k get clusterrole cluster-admin -o yaml
> apiVersion: rbac.authorization.k8s.io/v1
> kind: ClusterRole
> metadata:
>   annotations:
>     rbac.authorization.kubernetes.io/autoupdate: "true"
>   creationTimestamp: "2022-02-04T06:30:06Z"
>   labels:
>     kubernetes.io/bootstrapping: rbac-defaults
>   name: cluster-admin
>   resourceVersion: "85"
>   uid: 9191759e-36f7-4e8e-83f6-067424b72dc3
> rules:
> - apiGroups:
>   - '*'
>   resources:
>   - '*'
>   verbs:
>   - '*'
> - nonResourceURLs:
>   - '*'
>   verbs:
>   - '*'

kubectl auth can-i create deployments --namespace kube-system
> yes
```

## Sample users
```
k get sa
> NAME      SECRETS   AGE
> default   1         6h49m

k get clusterrole
> NAME                                                                   CREATED AT
> admin                                                                  2022-02-04T13:55:20Z
> cluster-admin                                                          2022-02-04T13:55:20Z
> edit                                                                   2022-02-04T13:55:20Z
> ingress-nginx                                                          2022-02-04T13:55:28Z
> ingress-nginx-admission                                                2022-02-04T13:55:29Z
> ............
> view                                                                   2022-02-04T13:55:20Z

k create sa vasya
> serviceaccount/vasya created

k create sa petya
> serviceaccount/petya created

k get sa
> NAME      SECRETS   AGE
> default   1         158m
> petya     1         9m51s
> vasya     1         10m

k get sa vasya -o yaml
> apiVersion: v1
> kind: ServiceAccount
> metadata:
>   creationTimestamp: "2022-02-04T13:21:29Z"
>   name: vasya
>   namespace: default
>   resourceVersion: "18053"
>   uid: b0a7fff0-61a4-4646-92f7-0a5827c67bde
> secrets:
> - name: vasya-token-qklw8

k get secret vasya-token-qklw8 -o yaml
> apiVersion: v1
> data:
>   ca.crt: LS0tLS1CRUd....Q0FURS0tLS0tCg==
>   namespace: ZGVmYXVsdA==
>   token: ZXlKaGJHY2lP....Y25wVWxVM25KUQ==
> kind: Secret
> metadata:
>   annotations:
>     kubernetes.io/service-account.name: vasya
>     kubernetes.io/service-account.uid: b0a7fff0-61a4-4646-92f7-0a5827c67bde
>   creationTimestamp: "2022-02-04T13:21:29Z"
>   name: vasya-token-qklw8
>   namespace: default
>   resourceVersion: "18052"
>   uid: bd668786-bd6f-4553-aa11-b1051eec2c89
> type: kubernetes.io/service-account-token

$ echo "ZXlKaGJHY2lP....Y25wVWxVM25KUQ=="|base64 -d
> eyJhbGciO........DxcnpUlU3nJQ
```
Copy the output of the previous command, open K8s `Dashboard` and paste the token there  
> http auto-logins for some reason  
> http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/login  
> https does'n work - getting `localhost sent an invalid response. ERR_SSL_PROTOCOL_ERROR`  
> https://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login  
> This probably has something to do with `--enable-skip-login`  
> Start [here for more details](https://stackoverflow.com/questions/46664104/how-to-sign-in-kubernetes-dashboard)

Checking access
```
kubectl auth can-i create pods --as=vasya
> no
kubectl auth can-i get pods --as=vasya
> no
k apply -f ./binding-vasya.yaml 
> rolebinding.rbac.authorization.k8s.io/vasya created
k apply -f ./binding-petya.yaml 
> rolebinding.rbac.authorization.k8s.io/petya created

k get clusterrole view -o yaml

kubectl auth can-i get pods --as=system:serviceaccount:default:vasya
> yes
kubectl auth can-i create pods --as=system:serviceaccount:default:vasya
> no
kubectl auth can-i create pods --as=system:serviceaccount:default:petya
> yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:petya
> yes
```

## Configure user authentication using x509 certificates
### Create private key
```bash
openssl genrsa -out k8s_user.key 2048
```
### Create a certificate signing request
> Have to use double slash for -subj (`-subj "//CN=k8s_user"`) because  
> "the underlying libraries (coming from mingw) are trying to be smart  
> and convert arguments that look like paths to actual paths."  
> https://github.com/openssl/openssl/issues/8795  

```bash
openssl req -new -key k8s_user.key -out k8s_user.csr -subj "//CN=k8s_user"
```
### Sign the CSR in the Kubernetes CA.
We have to use the CA certificate and the key, which are usually in /etc/kubernetes/pki. But since we use minikube, the certificates will be on the host machine in ~/.minikube
```bash
openssl x509 -req -in k8s_user.csr \
-CA /c/Users/admin/.minikube/ca.crt \
-CAkey /c/Users/admin/.minikube/ca.key \
-CAcreateserial \
-out k8s_user.crt -days 500
```
> `ca.srl` gets created (updated?) under `/c/Users/admin/.minikube`

## Create user in kubernetes
```bash
kubectl config set-credentials k8s_user \
--client-certificate=k8s_user.crt --client-key=k8s_user.key
> User "k8s_user" set.
```
The corresponding user entry gets created in the `c:\Users\admin\.kube\config`
```
users:
...
- name: k8s_user
  user:
    client-certificate: c:\Users\admin\.minikube\k8s_user.crt
    client-key: c:\Users\admin\.minikube\k8s_user.key
...
```

## Set context for user
```bash
kubectl config set-context k8s_user --cluster=minikube --user=k8s_user
> Context "k8s_user" created.
```
The corresponding context gets created in the `c:\Users\admin\.kube\config`
```
contexts:
...
- context:
    cluster: minikube
    user: k8s_user
  name: k8s_user
...
```

## Edit ~/.kube/config
```bash
Change path
- name: k8s_user
  user:
    client-certificate: C:\Users\Andrey_Trusikhin\educ\k8s_user.crt
    client-key: C:\Users\Andrey_Trusikhin\educ\k8s_user.key
contexts:
- context:
    cluster: minikube
    user: k8s_user
  name: k8s_user

```
## Switch to use new context
```bash
kubectl config get-contexts
kubectl config use-context k8s_user
> Switched to context "k8s_user".
k get node
> Error from server (Forbidden): nodes is forbidden: User "k8s_user" cannot list resource "nodes" in API group "" at the cluster scope
k get po
> Error from server (Forbidden): pods is forbidden: User "k8s_user" cannot list resource "pods" in API group "" in the namespace "default"
```

## Bind role and clusterrole to the user
```
$ kubectl config use-context minikube
> Switched to context "minikube".
$ k apply -f ./binding.yaml 
> rolebinding.rbac.authorization.k8s.io/k8s_user created
$ kubectl config use-context k8s_user
> Switched to context "k8s_user".
$ k get po
> No resources found in default namespace.
```
The user is now binded to the admin ClusterRole

## Resources and Verbs
```
$ kubectl api-resources --sort-by name -o wide | grep -E 'deploy|pod'
> NAME                              SHORTNAMES   APIVERSION                             NAMESPACED   KIND                             VERBS
> deployments                       deploy       apps/v1                                true         Deployment                       [create delete deletecollection get list patch update watch]
> horizontalpodautoscalers          hpa          autoscaling/v1                         true         HorizontalPodAutoscaler          [create delete deletecollection get list patch update watch]
> poddisruptionbudgets              pdb          policy/v1                              true         PodDisruptionBudget              [create delete deletecollection get list patch update watch]
> pods                              po           v1                                     true         Pod                              [create delete deletecollection get list patch update watch]
> podsecuritypolicies               psp          policy/v1beta1                         false        PodSecurityPolicy                [create delete deletecollection get list patch update watch]
> podtemplates                                   v1                                     true         PodTemplate                      [create delete deletecollection get list patch update watch]
```

# Homework
* Create users deploy_view and deploy_edit. Give the user deploy_view rights only to view deployments, pods. Give the user deploy_edit full rights to the objects deployments, pods.
* Create namespace prod. Create users prod_admin, prod_view. Give the user prod_admin admin rights on ns prod, give the user prod_view only view rights on namespace prod.
* Create a serviceAccount sa-namespace-admin. Grant full rights to namespace default. Create context, authorize using the created sa, check accesses.

[Assignment 1 Deploy users](#deploy-users)  
[Assignment 2 Namespace resources](#namespace-resources)  
[Assignment 3 serviceAccount](#serviceaccount)  


## Deploy users
* Create users deploy_view and deploy_edit. Give the user deploy_view rights only to view deployments, pods. Give the user deploy_edit full rights to the objects deployments, pods.

> My understanding of the task: both users should be able to manupilate  
> the objects in all namespaces across the cluster  

### Creatig certificates and roles
```
openssl genrsa -out deploy_view_user.key 2048
openssl req -new -key deploy_view_user.key -out deploy_view_user.csr -subj "//CN=deploy_view_user"
openssl genrsa -out deploy_edit_user.key 2048
openssl req -new -key deploy_edit_user.key -out deploy_edit_user.csr -subj "//CN=deploy_edit_user"

openssl x509 -req -in deploy_view_user.csr \
-CA /c/Users/admin/.minikube/ca.crt -CAkey /c/Users/admin/.minikube/ca.key \
-CAcreateserial -out deploy_view_user.crt -days 500
openssl x509 -req -in deploy_edit_user.csr \
-CA /c/Users/admin/.minikube/ca.crt -CAkey /c/Users/admin/.minikube/ca.key \
-CAcreateserial -out deploy_edit_user.crt -days 500
```

### Adding the users and the contexts to the `config` file
```
kubectl config set-credentials deploy_view_user \
--client-certificate=/c/deploy_view_user.crt --client-key=/c/deploy_view_user.key
> User "deploy_view_user" set.
kubectl config set-credentials deploy_edit_user \
--client-certificate=/c/deploy_edit_user.crt --client-key=/c/deploy_edit_user.key
> User "deploy_edit_user" set.
```

### Adding roles and contexts
```
k apply -f ./role-read.yaml
> clusterrole.rbac.authorization.k8s.io/deploy-view created
k apply -f ./role-edit.yaml
> clusterrole.rbac.authorization.k8s.io/deploy-edit created

$ k get clusterrole | grep deploy-
> deploy-edit                                                            2022-02-06T15:14:21Z
> deploy-view                                                            2022-02-06T14:13:11Z

kubectl config set-context deploy_view_user --cluster=minikube --user=deploy_view_user
> Context "deploy_view_user" created.
kubectl config set-context deploy_edit_user --cluster=minikube --user=deploy_edit_user
> Context "deploy_edit_user" created.
```

### Applying rolebindings
```
$ k apply -f ./rolebinding-read.yaml 
> rolebinding.rbac.authorization.k8s.io/deploy_view created
$ k apply -f ./rolebinding-edit.yaml 
> rolebinding.rbac.authorization.k8s.io/deploy_edit created

$ k get clusterrole | grep deploy-
> deploy-edit                                                            2022-02-06T15:14:21Z
> deploy-view                                                            2022-02-06T14:13:11Z  

$ kubectl get rolebinding,clusterrolebinding | grep deploy-
> rolebinding.rbac.authorization.k8s.io/deploy_edit_user   ClusterRole/deploy-edit   4h25m
> rolebinding.rbac.authorization.k8s.io/deploy_view_user   ClusterRole/deploy-view   5h15m
```

### Creating sample resources to test RBAC
```
k apply -f ./deployment
> deployment.apps/web created
> configmap/nginx-configmap created

$ kubectl config use-context minikube
> Switched to context "minikube".

$ k get deploy,po,cm
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   1/1     1            1           17s
> NAME                      READY   STATUS    RESTARTS   AGE
> pod/web-78bf47f5f-24njr   1/1     Running   0          17s
> NAME                         DATA   AGE
> configmap/kube-root-ca.crt   1      80m
> configmap/nginx-configmap    1      17s
```

### Testing the users
```
$ k config use-context deploy_view_user
> Switched to context "deploy_view_user".

$ k get deploy,po
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   1/1     1            1           45m
> NAME                      READY   STATUS    RESTARTS   AGE
> pod/web-78bf47f5f-24njr   1/1     Running   0          45m

$ k get cm
> Error from server (Forbidden): configmaps is forbidden: User "deploy_view_user" cannot list resource "configmaps" in API group "" in the namespace "default"

$ k edit deploy web
> error: deployments.apps "web" could not be patched: deployments.apps "web" is forbidden: User "deploy_view_user" cannot patch > resource "deployments" in API group "apps" in the namespace "default"
> You can run `kubectl.exe replace -f C:\Users\admin\AppData\Local\Temp\kubectl.exe-edit-3675539232.yaml` to try this update again.

$ k config use-context deploy_edit_user
> Switched to context "deploy_edit_user".

$ k get deploy,po
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   1/1     1            1           48m
> NAME                      READY   STATUS    RESTARTS   AGE
> pod/web-78bf47f5f-24njr   1/1     Running   0          48m

$ k get cm
Error from server (Forbidden): configmaps is forbidden: User "deploy_edit_user" cannot list resource "configmaps" in API group "" in the namespace "default"

$ k edit deploy web
deployment.apps/web edited
```

## Namespace resources
* Create namespace prod. Create users prod_admin, prod_view. Give the user prod_admin admin rights on ns prod, give the user prod_view only view rights on namespace prod.

### Creatig certificates and roles
```
openssl genrsa -out prod_admin_user.key 2048
openssl req -new -key prod_admin_user.key -out prod_admin_user.csr -subj "//CN=prod_admin_user"
openssl genrsa -out prod_view_user.key 2048
openssl req -new -key prod_view_user.key -out prod_view_user.csr -subj "//CN=prod_view_user"

openssl x509 -req -in prod_admin_user.csr \
-CA /c/Users/admin/.minikube/ca.crt -CAkey /c/Users/admin/.minikube/ca.key \
-CAcreateserial -out prod_admin_user.crt -days 500
openssl x509 -req -in prod_view_user.csr \
-CA /c/Users/admin/.minikube/ca.crt -CAkey /c/Users/admin/.minikube/ca.key \
-CAcreateserial -out prod_view_user.crt -days 500
```

### Adding the users and the contexts to the `config` file
```
kubectl config set-credentials prod_admin_user \
--client-certificate=/c/prod_admin_user.crt --client-key=/c/prod_admin_user.key
> User "prod_admin_user" set.
kubectl config set-credentials prod_view_user \
--client-certificate=/c/prod_view_user.crt --client-key=/c/prod_view_user.key
> User "prod_view_user" set.

kubectl config set-context prod_admin_user --cluster=minikube --user=prod_admin_user
> Context "prod_admin_user" created.
kubectl config set-context prod_view_user --cluster=minikube --user=prod_view_user
> Context "prod_view_user" created.
```

### Applying the roles
```
$ k apply -f rolebinding-prod-admin.yaml 
> rolebinding.rbac.authorization.k8s.io/prod_admin_user created
$ k apply -f rolebinding-prod-view.yaml 
> rolebinding.rbac.authorization.k8s.io/prod_view_user created
$ k -n prod get rolebinding,clusterrolebinding | grep prod
> rolebinding.rbac.authorization.k8s.io/prod_admin_user   ClusterRole/admin   41s
> rolebinding.rbac.authorization.k8s.io/prod_view_user    ClusterRole/view    38s
```

### Creating sample resources to test RBAC
```
$ k -n prod apply -f ./deployment/
> deployment.apps/web created
> configmap/nginx-configmap created
```

### Testing RBAC for the users
There is a deploy and a pod in the `prod` namespace
```
$ k -n prod get deploy,po
> NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/web   1/1     1            1           16s
> NAME                      READY   STATUS    RESTARTS   AGE
> pod/web-78bf47f5f-rj7d8   1/1     Running   0          16s
```
Testing the `prod_view_user`:
- can't read from the `default` namespace  
- can read from the `prod` namespace  
- can't delete from the `prod` namespace    
```
$ k config use-context prod_view_user
> Switched to context "prod_view_user".

$ k get po
> Error from server (Forbidden): pods is forbidden: User "prod_view_user" cannot list resource "pods" in API group "" in the namespace "default"

$ k -n prod get po
> NAME                  READY   STATUS    RESTARTS   AGE
> web-78bf47f5f-rj7d8   1/1     Running   0          52s

$ k -n prod delete po web-78bf47f5f-rj7d8
> Error from server (Forbidden): pods "web-78bf47f5f-rj7d8" is forbidden: User "prod_view_user" cannot delete resource "pods" in API group "" in the namespace "prod"
```

Testing the `prod_admin_user`:
- can't read from the `default` namespace  
- can read from the `prod` namespace  
- can delete from the `prod` namespace    
```
$ k config use-context prod_admin_user
> Switched to context "prod_admin_user".

$ k get po
> Error from server (Forbidden): pods is forbidden: User "prod_admin_user" cannot list resource "pods" in API group "" in the namespace "default"

$ k -n prod get po
> NAME                  READY   STATUS    RESTARTS   AGE
> web-78bf47f5f-rj7d8   1/1     Running   0          5m12s

$ k -n prod delete po web-78bf47f5f-rj7d8
pod "web-78bf47f5f-rj7d8" deleted
```

## serviceAccount


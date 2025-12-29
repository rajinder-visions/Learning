# What is Kubernetes
Kubernetes is Open Source Container Orchestration engine for automating deployment, scaling and management of containerzied applications.

## Components of Kubernetes
Kubernetes Consists of Control Plane and Worker Node. Their Components are given below:-
### Control Plane components:-
<pre>
i) etcd 
ii) Scheduler
iii) Kube-api
iv) Controller-Manager
</pre>
### Worker Node Components:-
<pre>
i) kube-proxy
ii) Kubelet
iii) kube-Runtime
</pre>

## What is Objects in Kubernetes.
<pre>
Objects are Persistent entities in Kubernetes. Kubernetes uses these entities to represent the state of cluster. Specially they can describe:-
<li>
  What Continer applications are running and on which nodes.
  What are the reseources avaialable to those applications.
  The policies around how those applications behave like restart, upgrade and fault-tolerence.
</li>
</pre>

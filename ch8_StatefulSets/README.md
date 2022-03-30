# StatefulSets: for 'stateful applications' 
Simple question. With what we've covered so far, can you employ a ReplicaSet to replicate the database pod? No. Here's why

## Replicationg stateful pods
ReplicaSets create multiple pod replicas from a single pod template; therefore the replicas don't differ from each apart from their name and IP address.
And more crucially, if the pod template includes a volume(which is necessary for database), all replicas will point to the same PVC and PV. 

You may be thinking of:
- **creating pods manually** : but then it's not gonna be rescheduled when they disappear!
- **using one replicaset per pod** : A lot of works to manage all of them and no scailability. 
- **using multiple directories in the same volume** : you can't tell each instance what directory they should use with shared storage volume being a bottleneck.

### Providing a stable identity for each pod
Pod can be killed time to time and replaced. But still a lot of, for example, NoSQL database require a stable network identity.<br>
For those kinds of applications, administrators need to list all the other cluster members and their IP in each membmer's configuration.<br>
So the IP address must be at least searchable or predictable. <br>

#### Using a dedicated service for each pod instance
How can you give a stable identity for each pod?<br>
You may be thinking of:
- providing each cluster member with dedicated Service object : similar idea to creating ReplicaSet for individual storage. 

But this solution is not only ugly but never do solve every problem such as individual pods not knowing which Service they are exposed through.<br><br>

Given all of these, Kubernetes devised a means to get around to this : **StatefulSets**

## Understanding StatefulSets
StatefulSets are specifically tailored to applications where instances of the apllications must be treated as **non-fungible** individuals.<br>
It makes sure pods are rescheduled in such a way that they retain their identity and state.<br>
It has also :
- replicas for desired replica count 
- template for pod

But then how can they have predictable identity? 

### Providing a stable network identity
Each pod created by a StatefulSet is assigned an **"ordinal index"**(zero-based)<br>

<img src="predictableName.png"><br>

#### Introducing the governing service
But it's not all about the pods having a predictable name and hostname.<br>
stateful pods sometimes need to be addressable by their hostname. <br>
Plus, you would want to operate on a specific pod from the group because<br>
they differ from each other.<br><br>

For this reason, a Statefulset requires you to create a governing **headless Service,**<br>
which provides the actual network identity to each pod.<br>
Through this Service, each pod gets its own DNS entry, so its peers and other clients<br>
can address the pod by its hostname.<br><br>

For example, if governing Service belongs to the *default* namespace and called *foo*,<br>
and one of the pods is called *A-0*, you can reach the pod through its FQDN which is :

    a-0.foo.default.svc.cluster.local

Additionally, you can also use DNS to look up all the StatefulSet's pods names by looking up **SRV records** for the foo.default.svc.cluster.local domain. For your information, SRV is :

    Service record (SRV record) is a specification of data in the Domain Name System defining the location, i.e., the hostname and port number, of servers for specified services.


#### Replacing disconnected pods
StatefulSet makes sure the disconnected pods are replaced with a new instance. But in contrast to ReplicaSets, the replacement pod gets the same name and hostname as the pod that has disappeared. <br>
<img src="replacement.png"><br>


#### Scaling a StatefulSet
Scaling the StatefulSet creates a new pod instance with the next unused ordinal index. if you scale up from two to three instances, the new instance will get index 2.<br><br>

The nice thing about scaling down a StatefulSet is the fact that you know what pod will be removed. <br><br>
<img src="scaledown.png"><br>

Note that StatefulSets scale down only one pod instance at a time in case distributed data store otherwise losing data. <br><br>
For the same erason, StatefulSet also never permit scale-down operations if any of the instances are unhealthy.

### Providing stable dedicated storage to each stateful instance
Now you've seen how to ensure stateful pods have a stable identity. But what about storage?<br>
Because PersistentVolumeClaims(PVCs) map to PersistentVolumes(PVs) one-to-one,<br>
each pod of a StatefulSet needs to reference a different PVC to have its own separate PersistentVolume.<br><br>

To do that, surely you're not expected to create as many PVCs as the number of pods you plan to have in<br>
StatefulSet upfront - of cource not. 

#### Teaming up Pod templates with VolumeClaim templates
<img src="VolumeClaimTemplates.png"><br>
The PVs for the claim can either be provisioned up-front or just in time through dynamic provisioning

#### Understanding the creation and deletion of PVCs
Scaling up a StatefulSet by one creates two or more API objects.<br>
Scaling down, however, deletes only the pod, leaving the claims alone.<br>
The reason for this is obvious; to protect the data stored in PV.<br>
For this reason, you're required to delete PVCs manually if in need.

#### Reattaching the PVC to the new instance of the same pod
The fact that the PVC remains after a scale-down means a subsequent scale-up can reattach the same claim along with the bound PV and its contents to the new pod instance. If you accidentally scale down a StatefulSet, you can und the mistake by scaling up again and the new pod will get the same persisted state again. <br>
<img src="Reattachment.png"><br>

### Understanding StatefulSet guarantees
Aside from stable identity and storage, StatefulSets also have different guarantees regarding their pods. 

#### Implications of stable identity and storage
While regular, stateless pods are fungible, stateful pods are NOT.<br>
Stateful pod is supposed to be replaced with an identical pod when things happen.<br>

    But what if K8S can't be sure about the state of the pod?

If it creates a replacement pod with the same identity, two instances of the app with the same identity might be running in the system.<br>
The two would also be bound to the same storage.

#### Introducing StatefulSet's At-Most-One-Semantics
K8S mut thus take great care to ensure two stateful pod instances are never running with the same identity.<br>
A StatefulSet must guarantee *at-most-one* semantics for stateful pod instances.<br>
What does that mean? 

    This means a StatefulSet must be absolutely certain that a pod is no longer running before it can create a replacement pod. 

Before we demonstrate this, you need to create a StatefulSet and see how it behaves. 

## Using a StatefulSet
## kubemark 搭建测试集群和性能测试

Kubemark是K8s官方提供的一个对K8s集群进行性能测试的工具。它可以模拟出一个K8s cluster（Kubemark cluster），不受资源限制，从而能够测试的集群规模比真实集群大的多。这个cluster中master是真实的机器，所有的nodes是Hollow nodes。Hollow nodes执行的还是真实的K8s程序，只是不会调用Docker，因此测试会走一套K8s API调用的完整流程，但是不会真正创建pod。

Kubermark是在模拟的Kubemark cluster上跑E2E测试，从而获得集群的性能指标。Kubermark cluster的测试数据，虽然与真实集群的稍微有点误差，不过可以代表真实集群的数据。因此，可以借用Kubermark，直接在真实集群上跑E2E测试，从而对我们真实集群进行性能测试。

#### kubemark 架构
kubemark cluster 包括两部分： 一个真实的master集群和一系列 “hollow” node， "hollow node" 只是模拟了kubelet的行为，并不是真正的node，不会启动任何的pod和挂载卷。
一般搭建kubemark 测试集群需要一个真实的集群（external cluster）和一个 kubemark master。hollowNode 以pod的形式运行在 external cluster 中，并连接 kubemark master 将自己注册为kubemark master 的 node。

kubemark master 结构图：
![kubemark](https://upload-images.jianshu.io/upload_images/8621205-2e861df851d8d198.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 搭建 kubemark 流程
搭建详细流程参考[k8s 官方文档](https://github.com/kubernetes/community/blob/master/contributors/devel/kubemark-guide.md)


1. 先搭建一个真实的集群，称为 real cluster，用来部署 kubemark pod；再搭建一个带测试集群，该待测试集群只有master节点，需要通过 kubemark pod 模拟node。
2. 配置 `default_config.sh` 下的配置选项，然后执行 `./statr_kubemark.sh` 创建 kubemark pod, 当 kubemark pod ready 后，查看测试集群可以看到有对应的node注册成功
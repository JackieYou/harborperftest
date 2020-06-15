package harbor

import (
	"fmt"
	"os/exec"
	"sync"
	"time"

	"gopkg.in/cheggaaa/pb.v1"

	"github.com/spf13/cobra"
	"k8s.io/api/core/v1"
	"k8s.io/client-go/tools/clientcmd"

	"log"
	"perftest/pkg/essh"
	"perftest/pkg/report"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

var (
	image      string
	kubeconfig string
	keypath    string
	concurrent int
	cache      bool
	clients    []*essh.SSHClient
	wg         sync.WaitGroup
)

func init() {
	pullimageCmd.Flags().StringVar(&image, "image", "", "set pull image")
	pullimageCmd.Flags().StringVar(&kubeconfig, "kubeconfig", "", "")
	pullimageCmd.Flags().StringVar(&keypath, "keypath", "/root/new", "")
	pullimageCmd.Flags().BoolVar(&cache, "cache", false, "")
	pullimageCmd.Flags().IntVar(&concurrent, "concurrent", 1, "")
}

var pullimageCmd = &cobra.Command{
	Use:   "pullimage",
	Short: "harbor pull image test",
	Long:  "harbor pull image test",
	Run: func(cmd *cobra.Command, args []string) {
		if cache {
			pullCacheImages()
		} else {
			pullImages()
		}

	},
}

func pullCacheImages() {
	pullimage := fmt.Sprintf("docker pull %s", image)
	fmt.Println("pullCacheImages", pullimage)
	bar := pb.New(concurrent)
	bar.Format("Bom !")
	bar.Start()

	r := newReport()

	for i := 0; i < concurrent; i++ {
		wg.Add(1)

		go func() {
			defer wg.Done()
			st := time.Now()
			cmd := exec.Command("/bin/bash", "-c", pullimage)
			out, err := cmd.Output()

			if err != nil {
				log.Printf("pull image error: %v (%s)", err, out)
			}

			end := time.Now()
			r.Results() <- report.Result{Err: err, Start: st, End: end}
			bar.Increment()
		}()
	}
	rc := r.Run()
	wg.Wait()

	close(r.Results())
	bar.Finish()
	fmt.Println(<-rc)

}

func pullImages() {
	pullimage := fmt.Sprintf("docker pull %s", image)
	fmt.Println("pull images", pullimage)

	nodes := getNodes()

	for _, node := range nodes {
		c, err := essh.GetSSHClient(node.ObjectMeta.Name, "", keypath)
		if err != nil {
			panic(err)
		}
		clients = append(clients, c)
	}

	bar := pb.New(len(nodes))
	bar.Format("Bom !")
	bar.Start()

	r := newReport()
	for i := range clients {
		wg.Add(1)

		go func(c *essh.SSHClient) {
			defer wg.Done()
			st := time.Now()
			out, errmsg, err := c.ExecCmd(pullimage)
			if err != nil {
				log.Printf("on node: %s, pull image error: %v (%s, %s)", c.Host, err, out, errmsg)
				//c.ExecCmd("systemctl restart docker")
			}
			end := time.Now()
			log.Printf("node %s pull image success, duration: %v", c.Host, end.Sub(st))
			r.Results() <- report.Result{Err: err, Start: st, End: end}
			bar.Increment()
		}(clients[i])
	}
	rc := r.Run()
	wg.Wait()

	close(r.Results())
	bar.Finish()
	fmt.Println(<-rc)
}

func getNodes() []v1.Node {
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		panic(err.Error())
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	nodeList, err := clientset.CoreV1().Nodes().List(metav1.ListOptions{})
	if err != nil {
		panic(err)
	}

	nodes := make([]v1.Node, 0)
	for _, node := range nodeList.Items {
		if node.GetLabels()["kubernetes.io/role"] != "master" {
			nodes = append(nodes, node)
		}
	}

	return nodes
}

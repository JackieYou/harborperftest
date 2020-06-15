package essh

import (
	"bytes"
	"io/ioutil"
	"log"
	"net"

	"golang.org/x/crypto/ssh"
)

type SSHClient struct {
	Host     string
	Port     string
	KeyFile  string
	Password string
	*ssh.Client
}

const (
	defaultPort = "22"
)

func (sc *SSHClient) ExecCmd(cmd string) (out, errmsg string, err error) {
	session, err := sc.NewSession()
	if err != nil {
		log.Fatal("Failed to create session: ", err)
	}
	defer session.Close()

	var b bytes.Buffer
	var outerr bytes.Buffer

	session.Stdout = &b
	session.Stderr = &outerr

	if err := session.Run(cmd); err != nil {
		return b.String(), outerr.String(), err
	}
	return b.String(), outerr.String(), nil
}

func (sc *SSHClient) XExecCmd(cmd string, session *ssh.Session) (out, errmsg string, err error) {
	var b bytes.Buffer
	var outerr bytes.Buffer

	session.Stdout = &b
	session.Stderr = &outerr

	if err := session.Run(cmd); err != nil {
		return b.String(), outerr.String(), err
	}
	return b.String(), outerr.String(), nil
}

func GetSSHClient(host, port, keypath string) (*SSHClient, error) {
	if port == "" {
		port = defaultPort
	}
	key, err := ioutil.ReadFile(keypath)
	if err != nil {
		log.Fatalf("unable to read private key: %v", err)
	}
	// Create the Signer for this private key.
	signer, err := ssh.ParsePrivateKey(key)
	if err != nil {
		log.Fatalf("unable to parse private key: %v", err)
	}

	config := &ssh.ClientConfig{
		User: "root",
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
			return nil
		},
	}
	//log.Println("conn addr:", net.JoinHostPort(host, port))

	sshClient, err := ssh.Dial("tcp", net.JoinHostPort(host, port), config)
	if err != nil {
		log.Fatalf("unable to connect: %v", err)
	}
	return &SSHClient{
		Host:   host,
		Port:   port,
		Client: sshClient,
	}, nil
}

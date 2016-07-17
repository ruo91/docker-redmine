# Dockerfile - Redmine
Integrate Nginx + Redis + MariaDB with Redmine

#### Usage
----------
```sh
[root@ruo91 ~]# git clone https://github.com/ruo91/docker-redmine.git /opt
[root@ruo91 ~]# docker build --rm -t redmine:latest /opt/docker-redmine
[root@ruo91 ~]# docker run -d --name="redmine" -h "redmine" -p 80:80 redmine:latest
```

#### Version
------------
latest

#### License
-------
MIT
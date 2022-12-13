# some script

## Automatic installation
Clone the project and select neutral to do the following to install the components you need, currently all single point!

### mysql

```bash
$ cd mysql
$ bash mysql_install.sh 
mysql.sh [online|offline] <mysql version>
    online  Online Installation
            option 5.7 or 8.0
    offline Offline Installation
            Only version 5.7 is supported
e,g
    mysql.sh online 8.0
```

### pinpoint

```bash
$ cd pinpoint
$ bash install.sh
```

### redis

```bash
$ cd redis
$ bash redis.sh
install <single | more | cluster>  port[s]
    single  Single instance deployment
            Only the first port you pass in will be used.
    more    Multi-instance deployment
            You need to pass in multiple ports, separated by Spaces.
    cluster Cluster Deployment
            You need an even number of ports, at least six.
```




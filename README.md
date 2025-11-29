# synology-private_ca-certificate-renewal
Synology NAS seems to be a consumer-oriented device, and the automatic certificate
renewal configuration possibilities are limited: You can easily configure it to get
and renew certificates from letsencrypt, but using a private CA would require using
the ACME DNS-01 challenge. That, in turn means that the NAS will need to be able to
modify the publicly-visible DNS, which might not be desirable.

The following setup makes it possible to use short-lived certificates from your own private CA. It also follows good security practices by not usint the root account for everything. Insted the non-root user account, `certadmin` is used.

The reason for why HTTP challenge does not work out-of-the-box is that you cannot serve your own  `.well-known/acme-challenge` with your own site(s). NAS seems to have a nginx, with configuration such as this, which prevents the path ever to be seen by our own site:
```
       location ^~ /.well-known/acme-challenge {
            root /var/lib/letsencrypt;
            default_type text/plain;
 ```
However, we can use that to our advantage, if we just accept that the root will be `/var/lib/letsencrypt`. Then the certificate renewal with acme.sh will look someting like this:
```
acme.sh --issue --webroot /var/lib/letsencrypt \
    -d nas.internal.example.com \
    --server https://ca.internal.example.com/acme/acme/directory \
    --ca-bundle ~certadmin/internalroot.crt
```
This assumes a few things:
- you have set up a user `certadmin` on the NAS
- have copied you privat CA root cert to the home
- your DNS points correctly to `nas.internal.example.com`
- have created the directory `/var/lib/letsencrypt` on the NAS, and set it with permissions that allow certadmin to write there.
- and you obviously have your own private CA online

This should get you the certificates. At this stage they are whereever you have decided to make acme.sh store them. Here we will use `~certadmin/acme/nas.internal.example.com_ecc`

The next thing is to get these certs to be used in the NAS. For that this repo includes the script `acme-certificate-install.sh` which could be placed in /usr/local/sbin/. That directory did not exist, so it might be a safe place even for upgrades.

Once the script is in place, you can register it with acme.sh and use it as the reload command with:

`acme.sh --install-cert   -d nas.intenal.example.com --reloadcmd "sudo /usr/local/sbin/acme-certificate-install.sh nas.internal.example.com"`

Since you want to launch that reaload command as the `certadmin` user, you will need to make sure passwordless sudo is possible for that command, for the user `certadmin`

Once `acme.sh --install` workd, you should be able to run just the acme.sh in "cron" mode as the user `certadmin` to renew the certs. However, if you are using short-lived certs (24h for example), acme.sh will miserably fail to understand that they are about to expire soon, and will not renew them in time. A bug that some surely will want to call a feature. Thus the simplest workaround could to run the the renewal every 8 hours with the --force flag, so you will get a new cert and a nginx reload every 8 hours. Something like this, but with the --home fixed to your environment:

`/usr/local/share/acme.sh/acme.sh --cron --force --home ~certadmin/acme`

You can create the task for this with the GUI to launch every 8 hours.
# synology-private_ca-certificate-renewal
Synology NAS seems to be a consumer-oriented device, and the automatic certificate
renewal configuration possibilities are limited. You can easily configure it to get
and renew certificates from letsencrypt, but using a private CA would require using
the ACME DNS-01 challenge. That, in turn means that the NAS will need to be able to
modify the DNS, which might not be desirable.

The following setup tries to make the certificate management be done with a non-root 
user account, `certadmin`.

The reason for why HTTP challenge does not work out-of-the-box is that you cannot serve your own  `.well-known/acme-challenge` . NAS seems to have a nginx, with configuration such as this"
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

This should get you the certificates. At this stage they are whereever you have decided to make acme.sh store them. Here we will use the example of `~certadmin/acme/nas.internal.example.com_ecc`

The next thing is to get these certs to be used in the NAS.
This example assumes that you only have the factory-installed self-signed certificate in use,
known as "default". If you have added other certificates,
this means that those new certs could now be used instead of the default one.
In that case the instructions will not work without changes,
so possibly the easiest way would be to remove the added certs, or at least make the "default" cert 
the cert that will be used for all services. That can be done through the NAS (DSM) GUI.

Included here is the renewal script, which seems to work for me. YMMV.

# Refresh a MISP instance

This script will only work on Ubuntu 18.04

No other support is planned.

# Requirements

* A MISP install. Ideally as directed in the [documentation](https://misp.github.io/MISP/INSTALL.ubuntu1804/) or installed via the [installer](https://github.com/MISP/MISP/blob/2.4/INSTALL/INSTALL.sh)
* Minimum MISP version 2.4.109
* bash
* jq
* dialog (optional)

# What does it do?

It will, by default, ask a bunch of questions what you want to do with your MISP instance.

Like: wipe all the data, re-generate SSL certificates, re-generate server SSH keys, rename base organisation, ...

# Usage

```bash
wget --no-cache -O /tmp/refresh.sh https://raw.githubusercontent.com/SteveClement/misp-refresh/master/refresh.sh ; bash /tmp/refresh.sh
```
# License

<img src="https://nonwhiteheterosexualmalelicense.org/502px-Asexual_symbol.svg.png" data-canonical-src="https://nonwhiteheterosexualmalelicense.org/502px-Asexual_symbol.svg.png" width="12" height="12" /> [NWHM](https://nonwhiteheterosexualmalelicense.org/) Licensed

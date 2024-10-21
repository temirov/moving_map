t# Moving Map

## Backend Setup

### Data sources

#### Taxes

1. [Quarterly Retail Sales Tax Data by County and City](https://catalog.data.gov/dataset/quarterly-retail-sales-tax-data-by-county-and-city)
1. [ZIP Codes by Area and District codes](https://postalpro.usps.com/ZIP_Locale_Detail)
1. [2023 TIGER/Line® Shapefiles: ZIP Code Tabulation Areas](https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2023&layergroup=ZIP+Code+Tabulation+Areas)


### .env

To set up a .env file drop it in the top folder and put the following variables. Define your own values.

```shell
POSTGRES_PORT=5432
POSTGRES_DB=us_weather
POSTGRES_USER=pguser
POSTGRES_PASSWORD=<mysecretpassword>
```

### Self-signed SSL certificates

```shell
sudo apt install mkcert
mkcert -install
mkcert computercat localhost computercat.tyemirov.lan $(hostname -I | awk '{print $1}')
```

The `mkcert install` command will produce /home/tyemirov/.local/share/mkcert/rootCA.pem which needs to be added to the root CA of the browsers which will be accessing the site.

Add `~/.local/share/mkcert/rootCA.pem` certificate to your browser.

For Chromium-based browsers running on Linux: 

```shell
sudo apt-get install libnss3-tools
certutil -A -n "My Root CA" -t "C,," -i ~/.local/share/mkcert/rootCA.pem -d sql:$HOME/.pki/nssdb
```

verify the installation

```shell
certutil -L -d sql:$HOME/.pki/nssdb
```

```shell
mkcert computercat localhost computercat.tyemirov.lan $(hostname -I | awk '{print $1}')
```

This command will produce a certificate to be added to the nginx configuration.
Move `computercat+3*.pem` certificates to `images/nginx/certs/`: `mv computercat+3* images/nginx/certs/`


# Moving Map

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
POSTGRES_PASSWORD=mysecretpassword
```

### SSL certificates

```shell
mkcert install
```

The `mkcert install` command will produce /home/tyemirov/.local/share/mkcert/rootCA.pem which needs to be added to the root CA of the browsers which will be accessing the site.

```shell
mkcert computercat localhost computercat.tyemirov.lan $(hostname -I | awk '{print $1}')
```

This command will produce a certificate to be added to the nginx configuration.

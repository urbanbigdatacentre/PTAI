# Accessibility indices in Great Britain 2023

This repository contains the code used to estimate the Great Britain Accessibility Indicators 2023 (AI23). 

The indices correspond to the first quarter of 2023. The geographic coverage  includes England, Scotland, and Wales. The geographic unit used is the 2011 LSOA/DZ version.

## Dataset

The dataset provides a suite of ready-to-use accessibility indicators to key services such as employment, general practices (GPs), hospitals, pharmacies, primary and secondary schools, supermarkets, main urban centres, and urban sub-centres. These indicators are available for 42,000 small area units across Great Britain, specifically at the Lower Super Output Area (LSOA) level in England and Wales, and the Data Zone (DZ) level in Scotland.


## Related resources and inputs

1. The travel time matrices for Great Britain (<https://github.com/urbanbigdatacentre/ttm_greatbritain>). This includes  various modes, namely: public transport, walk, and bicycle.
2. The location of the services are based on the PTAI22 project (<https://github.com/urbanbigdatacentre/access_uk_open>).
3. The indices are estimated using the `AccessUK` package (<https://github.com/urbanbigdatacentre/AccessUK>).
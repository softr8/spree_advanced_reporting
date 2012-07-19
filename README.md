# NOTES:

This branch is for use with Spree 1.1.0 and later.

For Spree 1.1.0 (and possibly later), use the master branch.
=======
For Spree 1.0.x, use the spree-1-0 branch.

Forked from what appeared to the be the most up to date for, and made the following general changes:

1. Removed PDF generation, which isn't working under Ruby 1.9.x
2. Removed the route that overrides the main admin overview page
3. Fixed a warning about ```ADVANCED_REPORTS``` being redefined
4. Fixed the en.yml translation lookups


# Note
This extension seems in flux, having many forks, but no official rails3 update.

# Advanced Reporting

Advanced reporting for Spree.

## Includes:
* Base reports of Revenue, Units, Profit into Daily, Weekly, Monthly, and Yearly increments
* Geo reports of Revenue, Units divided into states and countries
* Two "top" reports for top products and top customers
* The ability to limit reports by order date, "store" (multi-store extension), product, and taxon.
* The ability to export data in PDF or CSV format.

## Dependencies:
* Ruport and Ruport-util
* Google Visualization

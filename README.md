# Microsoft Business Central Extension

## Auto Reserve Demo

This extension allows for automatic creation of reservations for sales lines, given a sales line, an item that uses item tracking with lot nos. and an existing lot no.

## How to use

After installing the extension, create a sales order with an item line, using an item that uses lot numbers in its item tracking. Enter a lot no. in the new field `Lot No.` and select the action `Reserve Lot No.`. The new reservation entries of the status `Reservation` should now have been created.

To cancel a registration, enter the lot no. and use the action `Cancel Reservation for Lot No.`. This will change the status of the matching reservations to `Surplus`, where they will still register on the page `Item Tracking Lines`.

## Limitations

This extension makes a few assumptions of the item being reserved. Using it without adhering to these assumptions may have unintended results.

- It has an item tracking code that only requires a lot no.
- A reservation creates a pair of reservation entries, one from the sales order and one from a source that supplies the item. The supply source is always `Item Ledger Entry`.
- The lot no. can be assigned to multiple quantities and item ledger entries, but all items of the same lot no. are always in the same physical location and can't be separated.

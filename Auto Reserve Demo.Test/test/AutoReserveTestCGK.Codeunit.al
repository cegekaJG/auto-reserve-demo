codeunit 50050 "Auto Reserve Test CGK"
{
    Subtype = Test;

    [Test]
    [HandlerFunctions('GenericMessageHandler')]
    procedure AutoReserveLotNo()
    var
        recReservEntry: Record "Reservation Entry";
        sLotNo: Code[50];
        dQtyAvailableBase: Decimal;
    begin
        //[GIVEN] an item with item tracking
        SetupItem();
        //[GIVEN] one or more item ledger entries
        SetupItemLedgerEntry(4, 2);
        //[GIVEN] a customer
        SetupCustomer();
        //[GIVEN] a sales order containing the item
        CreateSalesOrder(1);
        //[GIVEN] a valid lot no.
        sLotNo := GetRandomLotNo(recSalesLine, dQtyAvailableBase);
        // set the quantity to the available quantity of the lot no.
        recSalesLine.Validate("Quantity (Base)", dQtyAvailableBase);
        recSalesLine.Modify(true);
        // enqueue the expected dialog text
        cuLibVarStorage.Enqueue(StrSubstNo(successMsg, dQtyAvailableBase, recSalesLine.Description, recSalesLine."Document No.", recSalesLine."Line No."));
        //[WHEN] autoreserving the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, false);
        //[THEN] create a reservation entry for the sales line
        Clear(recReservEntry);
        recReservEntry.SetRange("Lot No.", sLotNo);
        recReservEntry.SetRange("Reservation Status", "Reservation Status"::Reservation);

        VerifyReservedQty(recReservEntry, dQtyAvailableBase);
    end;

    [Test]
    [HandlerFunctions('CancelReservationConfirmhandler')]
    procedure AutoCancelLotNoReservation()
    var
        recReservEntry: Record "Reservation Entry";
        sLotNo: Code[50];
        dQtyAvailableBase: Decimal;
    begin
        //[GIVEN] an item with item tracking
        SetupItem();
        //[GIVEN] one or more item ledger entries
        SetupItemLedgerEntry(4, 2);
        //[GIVEN] a customer
        SetupCustomer();
        //[GIVEN] a sales order containing the item
        CreateSalesOrder(1);
        //[GIVEN] a valid lot no.
        sLotNo := GetRandomLotNo(recSalesLine, dQtyAvailableBase);
        // set the quantity to the available quantity of the lot no.
        recSalesLine.Validate("Quantity (Base)", dQtyAvailableBase);
        recSalesLine.Modify(true);
        //[GIVEN] a reservation entry using the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, true);
        // enqueue the expected dialog text & answer
        cuLibVarStorage.Enqueue(StrSubstNo(confirmMsg, sLotNo));
        cuLibVarStorage.Enqueue(true);
        //[WHEN] cancelling the reservation
        recSalesLine.CancelReservationOfLotNo(sLotNo, false);
        //[THEN] then revert reservation status to 'Surplus'
        Clear(recReservEntry);
        recReservEntry.SetRange("Lot No.", sLotNo);
        recReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);

        VerifyReservedQty(recReservEntry, dQtyAvailableBase);
    end;

    [Test]
    procedure TryReservingUnavailableLotNo()
    var
        sLotNo: Code[50];
        dQtyAvailableBase: Decimal;
    begin
        //[GIVEN] an item with item tracking
        SetupItem();
        //[GIVEN] one or more item ledger entries
        SetupItemLedgerEntry(4, 2);
        //[GIVEN] a customer
        SetupCustomer();
        //[GIVEN] a sales order containing the item
        CreateSalesOrder(2);
        //[GIVEN] a valid lot no.
        sLotNo := GetRandomLotNo(recSalesLine, dQtyAvailableBase);
        // set the quantity to the available quantity of the lot no.
        recSalesLine.Validate("Quantity (Base)", dQtyAvailableBase);
        recSalesLine.Modify(true);
        //[GIVEN] a reservation entry using the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, true);
        // go to next line in sales order
        recSalesLine.Next();
        //[WHEN] auto reserving the lot no. again
        //[THEN] then throw error
        asserterror recSalesLine.AutoReserveLotNo(sLotNo, false);
    end;

    [ConfirmHandler]
    procedure CancelReservationConfirmhandler(sQuestion: Text[1024]; var Reply: Boolean)
    begin
        cuLibAssert.ExpectedMessage(cuLibVarStorage.DequeueText(), sQuestion);
        Reply := cuLibVarStorage.DequeueBoolean();
    end;

    [MessageHandler]
    procedure GenericMessageHandler(sMessage: Text[1024])
    begin
        cuLibAssert.ExpectedMessage(cuLibVarStorage.DequeueText(), sMessage);
    end;

    procedure VerifyReservationOfSalesLineExists(var recReservEntry: Record "Reservation Entry"; var recSalesLine: Record "Sales Line")
    begin
        recSalesLine.SetReservationFilters(recReservEntry);
        cuLibAssert.RecordIsNotEmpty(recReservEntry);
    end;

    local procedure GetRandomLotNo(recSalesLine: Record "Sales Line"; var dQtyBase: Decimal): Code[50]
    var
        tempEntrySummary: Record "Entry Summary";
        tempTrackingSpec: Record "Tracking Specification" temporary;
        cuItemTrackDataCollection: Codeunit "Item Tracking Data Collection";
        iOffset: Integer;
    begin
        Clear(tempTrackingSpec);
        tempTrackingSpec.InitFromSalesLine(recSalesLine);
        cuItemTrackDataCollection.RetrieveLookupData(tempTrackingSpec, true);
        cuItemTrackDataCollection.GetTempGlobalEntrySummary(tempEntrySummary);

        dQtyBase := 0;

        if tempEntrySummary.IsEmpty then
            exit('');

        tempEntrySummary.FindFirst();

        tempEntrySummary.SetFilter("Total Available Quantity", '>0');
        iOffset := cuLibRandom.RandIntInRange(0, tempEntrySummary.Count - 1);

        if iOffset > 0 then
            tempEntrySummary.Next(iOffset);

        dQtyBase := tempEntrySummary."Total Available Quantity";
        exit(tempEntrySummary."Lot No.");
    end;

    procedure InsertItemJournalLine(var ItemJournalLine: Record "Item Journal Line"; sItemNo: Code[20]; iNoOfLotNos: Integer; iNoOfLines: Integer)
    var
        recItemJnlBatch: Record "Item Journal Batch";
        recItemJnlTemplate: Record "Item Journal Template";
        sLotNo: Code[50];
        iIndexLine, iIndexLot : Integer;
    begin
        cuLibInventory.SelectItemJournalTemplateName(
                recItemJnlTemplate, recItemJnlTemplate.Type::Item);
        cuLibInventory.SelectItemJournalBatchName(
            recItemJnlBatch, recItemJnlTemplate.Type, recItemJnlTemplate.Name);

        recItemJnlBatch.Validate("Item Tracking on Lines", true); // this procedure assigns tracking info in the journal lines
        recItemJnlBatch.Modify(true);

        for iIndexLot := 1 to iNoOfLotNos do begin
            sLotNo := CopyStr(cuLibRandom.RandText(10), 1, 10);

            for iIndexLine := 1 to iNoOfLines do begin
                cuLibInventory.CreateItemJournalLine(
                    ItemJournalLine, recItemJnlTemplate.Name, recItemJnlBatch.Name,
                    ItemJournalLine."Entry Type"::"Positive Adjmt.", sItemNo, cuLibRandom.RandIntInRange(2, 10));
                ItemJournalLine.Validate("Location Code", recLocation.Code);
                ItemJournalLine.Validate("Lot No.", sLotNo);
                ItemJournalLine.Modify(true);
            end;
        end;
    end;

    local procedure SetupCustomer()
    begin
        // Create customer
        cuLibSales.CreateCustomer(recCust);
    end;

    local procedure SetupItemLedgerEntry(iNoOfLotNos: Integer; iNoOfLines: Integer)
    var
        recItemJnlLine: Record "Item Journal Line";
    begin
        // Create item ledger entries
        InsertItemJournalLine(recItemJnlLine, recItem."No.", iNoOfLotNos, iNoOfLines);
        cuLibInventory.PostItemJournalLine(recItemJnlLine."Journal Template Name", recItemJnlLine."Journal Batch Name");
    end;

    local procedure SetupItem()
    begin
        // Create location
        cuLibWarehouse.CreateLocation(recLocation);
        cuLibInventory.UpdateInventoryPostingSetup(recLocation);
        // Create item tracking
        cuLibInventory.CreateItemTrackingCode(recItemTrackCode);
        recItemTrackCode.Validate("Lot Specific Tracking", true);
        recItemTrackCode.Modify(true);
        // Create item
        cuLibInventory.CreateItem(recItem);
        recItem.Validate("Item Tracking Code", recItemTrackCode.Code);
        recItem.Modify(true);
    end;

    local procedure CreateSalesOrder(iNoOfSalesLines: Integer)
    var
        iIndex: Integer;
    begin
        cuLibSales.CreateSalesOrderWithLocation(recSalesHdr, recCust."No.", recLocation.Code);

        for iIndex := 1 to iNoOfSalesLines do begin
            cuLibSales.CreateSalesLine(recSalesLine, recSalesHdr, "Sales Line Type"::Item, recItem."No.", 1);
            recSalesLine.Validate("Location Code", recLocation.Code);
            recSalesLine.Modify(true);
        end;
        recSalesLine.SetRecFilter();
        recSalesLine.SetRange("Line No.");
        recSalesLine.FindFirst();
    end;

    local procedure VerifyReservedQty(var recReservEntry: Record "Reservation Entry"; var dQtyAvailableBase: Decimal)
    var
        qtyUnequalErr: Label 'The reserved quantity does not match the total available quantity.\nAvailable: %1\nReserved: %2';
        dReservedQtyBase: Decimal;
    begin
        VerifyReservationOfSalesLineExists(recReservEntry, recSalesLine);

        recReservEntry.CalcSums("Qty. to Handle (Base)");
        dReservedQtyBase := recReservEntry."Qty. to Handle (Base)";

        cuLibAssert.AreEqual(-dReservedQtyBase, dQtyAvailableBase, StrSubstNo(qtyUnequalErr, dQtyAvailableBase, dReservedQtyBase));
    end;

    var
        recCust: Record Customer;
        recItem: Record Item;
        recItemTrackCode: Record "Item Tracking Code";
        recLocation: Record Location;
        recSalesHdr: Record "Sales Header";
        recSalesLine: Record "Sales Line";
        cuLibInventory: Codeunit "Library - Inventory";
        cuLibRandom: Codeunit "Library - Random";
        cuLibSales: Codeunit "Library - Sales";
        cuLibVarStorage: Codeunit "Library - Variable Storage";
        cuLibWarehouse: Codeunit "Library - Warehouse";
        cuLibAssert: Codeunit "Library Assert";
        confirmMsg: Label 'Are you sure you want to remove all reservations of lot no. "%1" for this sales line?', Comment = '%1: Lot No.';
        failMsg: Label 'Unable to reserve complete requested quantity of %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
        successMsg: Label 'Reserved %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
}

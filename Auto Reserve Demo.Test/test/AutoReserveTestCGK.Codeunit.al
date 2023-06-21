codeunit 50050 "Auto Reserve Test CGK"
{
    Subtype = Test;

    [Test]
    [HandlerFunctions('GenericMessageHandler')]
    procedure AutoReserveLotNo()
    var
        recReservEntry: Record "Reservation Entry";
        sLotNo: Code[50];
        dQtyBase: Decimal;
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
        sLotNo := GetRandomLotNo(recSalesLine, dQtyBase);
        // enqueue the expected dialog text
        cuLibVarStorage.Enqueue(StrSubstNo(successMsg, dQtyBase, recSalesLine.Description, recSalesLine."Document No.", recSalesLine."Line No."));
        //[WHEN] autoreserving the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, false);
        //[THEN] create a reservation entry for the sales line
        Clear(recReservEntry);
        recReservEntry.SetRange("Reservation Status", "Reservation Status"::Reservation);
        recReservEntry.SetRange("Lot No.", sLotNo);
        recReservEntry.SetRange("Qty. to Handle (Base)", dQtyBase);
        VerifyReservationOfLotNoExists(recReservEntry, recSalesLine);
    end;

    [Test]
    [HandlerFunctions('GenericMessageHandler')]
    procedure AutoCancelLotNoReservation()
    var
        recReservEntry: Record "Reservation Entry";
        sLotNo: Code[50];
        dQtyBase: Decimal;
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
        sLotNo := GetRandomLotNo(recSalesLine, dQtyBase);
        //[GIVEN] a reservation entry using the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, true);
        // enqueue the expected answer & dialog text
        cuLibVarStorage.Enqueue(true);
        cuLibVarStorage.Enqueue(StrSubstNo(confirmMsg, sLotNo));
        //[WHEN] cancelling the reservation
        recSalesLine.CancelReservationOfLotNo(sLotNo, false);
        //[THEN] then revert reservation status to 'Surplus'
        Clear(recReservEntry);
        recReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        recReservEntry.SetRange("Lot No.", sLotNo);
        recReservEntry.SetRange("Qty. to Handle (Base)", dQtyBase);
        VerifyReservationOfLotNoExists(recReservEntry, recSalesLine);
    end;

    [Test]
    [HandlerFunctions('GenericMessageHandler')]
    procedure TryReservingUnavailableLotNo()
    var
        sLotNo: Code[50];
        dQtyBase: Decimal;
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
        sLotNo := GetRandomLotNo(recSalesLine, dQtyBase);
        //[GIVEN] a reservation entry using the lot no.
        recSalesLine.AutoReserveLotNo(sLotNo, true);
        // go to next line in sales order
        recSalesLine.Next();
        // enqueue the expected dialog text
        cuLibVarStorage.Enqueue(StrSubstNo(failMsg, dQtyBase, recSalesLine.Description, recSalesLine."Document No.", recSalesLine."Line No."));
        //[WHEN] auto reserving the lot no. again
        recSalesLine.AutoReserveLotNo(sLotNo, false);
        //[THEN] then throw error
    end;

    [ConfirmHandler]
    procedure CancelReservationConfirmhandler(sQuestion: Text[1024]; var Reply: Boolean)
    // Call the following in the Test function
    //   LibraryVariableStorage.Enqueue('ExpectedConfirmText');
    //   LibraryVariableStorage.Enqueue(true); // or false, depending of the reply you want if below question is asked. Any other question will throw an error
    begin
        cuLibAssert.ExpectedMessage(cuLibVarStorage.DequeueText(), sQuestion);
        Reply := cuLibVarStorage.DequeueBoolean();
    end;

    [MessageHandler]
    procedure GenericMessageHandler(sMessage: Text[1024])
    begin
        cuLibAssert.ExpectedMessage(cuLibVarStorage.DequeueText(), sMessage);
    end;

    procedure VerifyReservationOfLotNoExists(var recReservEntry: Record "Reservation Entry"; var recSalesLine: Record "Sales Line")
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
        if bCustomerExists then
            exit;

        // Create customer
        cuLibSales.CreateCustomer(recCust);

        bCustomerExists := true;
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
        if bItemExists then
            exit;

        // Create location
        cuLibWarehouse.CreateLocation(recLocation);
        // Create item tracking
        cuLibInventory.CreateItemTrackingCode(recItemTrackCode);
        recItemTrackCode.Validate("Lot Specific Tracking", true);
        recItemTrackCode.Modify(true);
        // Create item
        cuLibInventory.CreateItem(recItem);
        recItem.Validate("Item Tracking Code", recItemTrackCode.Code);
        recItem.Modify(true);

        bItemExists := true;
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
        bCustomerExists, bItemExists : Boolean;
        confirmMsg: Label 'Are you sure you want to remove all reservations of lot no. "%1" for this sales line?', Comment = '%1: Lot No.';
        failMsg: Label 'Unable to reserve complete requested quantity of %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
        successMsg: Label 'Reserved %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
}

codeunit 50000 "Reservation Assistant CGK"
{
    procedure GetTempEntrySummaryFromSalesLine(
        var tempEntrySummary: Record "Entry Summary";
        var tempTrackingSpec: Record "Tracking Specification" temporary)
    var
        cuItemTrackDataCollection: Codeunit "Item Tracking Data Collection";
    begin
        cuItemTrackDataCollection.RetrieveLookupData(tempTrackingSpec, true);
        cuItemTrackDataCollection.GetTempGlobalEntrySummary(tempEntrySummary);
    end;

    procedure GetReservationStatusForSalesLine(recSalesLine: Record "Sales Line") enmReservStatus: Enum "Reservation Status"
    begin
        if recSalesLine."Document Type" in ["Sales Document Type"::Order, "Sales Document Type"::"Return Order"] then
            enmReservStatus := "Reservation Status"::Surplus
        else
            enmReservStatus := "Reservation Status"::Prospect;
    end;

    procedure GetTotalAvailableQuantityOfTrackingSpec(var recTrackingSpec: Record "Tracking Specification"): Decimal
    var
        tempEntrySummary: Record "Entry Summary";
    begin
        Clear(tempEntrySummary);

        GetTempEntrySummaryFromSalesLine(tempEntrySummary, recTrackingSpec);
        tempEntrySummary.SetTrackingFilterFromSpec(recTrackingSpec);
        if not tempEntrySummary.FindFirst() then
            exit(0)
        else
            exit(tempEntrySummary."Total Available Quantity");
    end;

    procedure ReserveSurplus(var tempTrackingSpec: Record "Tracking Specification" temporary; recReservEntry: Record "Reservation Entry") bFullAutoReserv: Boolean
    var
        cuReservMgt: Codeunit "Reservation Management";
        cuUoMMgt: Codeunit "Unit of Measure Management";
        dQtyToHandleBase, dQtyToHandle : Decimal;
    begin
        dQtyToHandleBase := recReservEntry."Qty. to Handle (Base)";
        dQtyToHandle := cuUoMMgt.CalcQtyFromBase(dQtyToHandleBase, recReservEntry."Qty. per Unit of Measure");
        Clear(cuReservMgt);
        cuReservMgt.SetCalcReservEntry(tempTrackingSpec, recReservEntry);
        cuReservMgt.AutoReserve(bFullAutoReserv, recReservEntry.Description, WorkDate(), dQtyToHandle, dQtyToHandleBase); // AutoReserve reserves all surplus reservation lines with matching tracking spec, no iteration necessary
    end;

    procedure CreateReservationEntryFromTrackingSpecification(var recTrackSpec: Record "Tracking Specification"; enmReservStatus: Enum "Reservation Status"; dQtyBase: Decimal): Boolean
    var
        recReservEntry: Record "Reservation Entry";
    begin
        if dQtyBase = 0 then
            exit;

        recReservEntry.Init();
        recReservEntry.TransferFields(recTrackSpec);
        recReservEntry."Reservation Status" := enmReservStatus;
        recReservEntry."Creation Date" := WorkDate();
        recReservEntry."Shipment Date" := WorkDate();
        recReservEntry."Created By" := UserId;
        recReservEntry."Quantity Invoiced (Base)" := 0;
        recReservEntry.Validate("Quantity (Base)", dQtyBase);
        recReservEntry.Positive := (recReservEntry."Quantity (Base)" > 0);
        recReservEntry."Entry No." := 0;
        recReservEntry.UpdateItemTracking();
        recReservEntry.Insert();

        exit(true);
    end;
}

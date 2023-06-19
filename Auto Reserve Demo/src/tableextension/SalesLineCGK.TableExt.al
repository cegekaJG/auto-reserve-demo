tableextension 50000 "Sales Line CGK" extends "Sales Line"
{
    procedure AutoReserveLotNo(sLotNo: Code[50])
    var
        recReservEntry: Record "Reservation Entry";
        tempTrackingSpec: Record "Tracking Specification" temporary;
        cuReservAssist: Codeunit "Reservation Assistant CGK";
        dQtyAvailableBase: Decimal;
        enmReservStatus: Enum "Reservation Status";
        failMsg: Label 'Unable to reserve complete requested quantity of %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
        successMsg: Label 'Reserved %1 %2 for Sales Line %3-%4.', Comment = '%1: Quantity, %2: Description, %3: Sales Doc No., %4: Sales Line No.';
        sMessage: Text;
    begin
        Rec.TestField(Type, Enum::"Sales Line Type"::Item);

        tempTrackingSpec.InitFromSalesLine(Rec);
        tempTrackingSpec."Lot No." := sLotNo; // Add tracking filters here

        // Get total available qty of item with lot no.
        dQtyAvailableBase := cuReservAssist.GetTotalAvailableQuantityOfTrackingSpec(tempTrackingSpec);

        // If available, create surplus reservation entry (for Item Tracking Lines)
        if dQtyAvailableBase > 0 then begin
            enmReservStatus := cuReservAssist.GetReservationStatusForSalesLine(Rec);
            if not cuReservAssist.CreateReservationEntryFromTrackingSpecification(tempTrackingSpec, enmReservStatus, -dQtyAvailableBase) then // invert quantity, since the reservation entry takes from the supply
                exit;
        end;

        // Find reservations for Sales Line with status Surplus and tracking info
        FilterSurplusReservationEntries(recReservEntry, tempTrackingSpec);
        recReservEntry.FindFirst();

        // Create reserved reservation entries from surplus reservation entries (for Reservation)
        if cuReservAssist.ReserveSurplus(tempTrackingSpec, recReservEntry) then
            sMessage := successMsg
        else
            sMessage := failMsg;

        Message(sMessage, tempTrackingSpec."Quantity (Base)", tempTrackingSpec.Description, Rec."Document No.", Rec."Line No.")
    end;

    procedure CancelReservationOfLotNo(sLotNo: Code[50])
    var
        recReservEntry: Record "Reservation Entry";
        cuReservEngineMgt: Codeunit "Reservation Engine Mgt.";
    begin
        Rec.TestField(Type, Enum::"Sales Line Type"::Item);

        Clear(recReservEntry);
        Rec.SetReservationFilters(recReservEntry);
        recReservEntry.SetRange("Reservation Status", recReservEntry."Reservation Status"::Reservation);
        recReservEntry.SetRange("Disallow Cancellation", false);
        recReservEntry.SetRange("Lot No.", sLotNo);

        recReservEntry.FindSet(); // Throw error if not found

        if not Confirm(StrSubstNo('Are you sure you want to remove all reservations of lot no. "%1" for this sales line?', sLotNo)) then
            exit;

        repeat
            cuReservEngineMgt.CancelReservation(recReservEntry); // Assumes source of matching line is Item Ledger Entry, see Reservation (Page 498), action "CancelReservationCurrentLine"
        until recReservEntry.Next() = 0;
    end;

    procedure FilterSurplusReservationEntries(var recReservEntry: Record "Reservation Entry"; var recTrackingSpec: Record "Tracking Specification")
    begin
        Rec.SetReservationFilters(recReservEntry);
        recReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        recReservEntry.SetTrackingFilterFromSpec(recTrackingSpec);
    end;
}

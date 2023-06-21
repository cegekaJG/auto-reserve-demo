pageextension 50000 "Sales Order Subform CGK" extends "Sales Order Subform"
{
    layout
    {
        addafter("Variant Code")
        {
            field("Lot No. CGK"; sLotNo)
            {
                Caption = 'Lot No.';
                ApplicationArea = All;
                Editable = Rec.Type = Rec.Type::Item;
            }
        }
    }
    actions
    {
        addfirst("&Line")
        {
            action("Reserve Lot No. CGK")
            {
                Caption = 'Reserve Lot No.';
                ApplicationArea = All;
                Image = Reserve;

                trigger OnAction()
                begin
                    Rec.AutoReserveLotNo(sLotNo, false);
                    Clear(sLotNo);
                end;
            }
            action("Cancel Reservation Of Lot No. CGK")
            {
                Caption = 'Cancel Reservation Of Lot No.';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                begin
                    Rec.CancelReservationOfLotNo(sLotNo, false);
                    Clear(sLotNo);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        Clear(sLotNo);
    end;

    var
        sLotNo: Code[50];
}

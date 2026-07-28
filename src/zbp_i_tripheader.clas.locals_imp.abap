******************* TriHeader - Saver Class *****************************
CLASS lsc_zi_tripheader DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS adjust_numbers REDEFINITION.

ENDCLASS.

CLASS lsc_zi_tripheader IMPLEMENTATION.

  METHOD adjust_numbers.
    " 1. Handle TripHeader Numbering (Incremental TRIP_0001)
    IF mapped-tripheader IS NOT INITIAL.
      " Get the current maximum ID from the database
      SELECT MAX( t_tripid ) FROM ztab_tripheader INTO @DATA(lv_max_tripid).

      DATA(lv_current_num) = CONV i( COND i( WHEN lv_max_tripid IS INITIAL
                                                THEN 0
                                            ELSE substring( val = lv_max_tripid off = 5 )
                                           )
                                   ).

      LOOP AT mapped-tripheader REFERENCE INTO DATA(lr_trip).
        lv_current_num += 1.
        " Format: TRIP_ + 4 digit padded number
        lr_trip->TripID = |TRIP_{ lv_current_num WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.
      ENDLOOP.
    ENDIF.



    " 2. Handle TripIncident Numbering (36-digit UUID)
    IF mapped-tripincident IS NOT INITIAL.
      LOOP AT mapped-tripincident REFERENCE INTO DATA(lr_incident).
        TRY.
            " Generate a standard 36-digit UUID
            lr_incident->IncidentID = cl_system_uuid=>create_uuid_c36_static( ).
            lr_incident->TripID = lr_incident->%tmp-TripID.
*            RAISE EXCEPTION TYPE cx_uuid_error.
          CATCH cx_uuid_error.
            " If UUID generation fails, we report the error back to the user
            APPEND VALUE #( %pid = lr_incident->%pid
                            %msg = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text       = 'UUID not generated for Incident Record(s)'
                                   )
                          ) TO reported-tripincident.
        ENDTRY.
      ENDLOOP.
    ENDIF.

    "3. Handle incident Attachment numbering (36-digit UUID)
    IF mapped-incidentattachment IS NOT INITIAL.
      LOOP AT mapped-incidentattachment REFERENCE INTO DATA(lr_att).
        TRY.
            " Generate a standard 36-digit UUID
            lr_att->FildId = cl_system_uuid=>create_uuid_c36_static( ).
            lr_att->IId = lr_att->%tmp-IId.
            lr_att->TripID = lr_att->%tmp-TripID.
*            RAISE EXCEPTION TYPE cx_uuid_error.
          CATCH cx_uuid_error.
            " If UUID generation fails, we report the error back to the user
            APPEND VALUE #( %pid = lr_att->%pid
                            %msg = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text       = 'UUID not generated for Incident Record(s)'
                                   )
                          ) TO reported-incidentattachment.
        ENDTRY.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

******************* TripIncident - hanlder Class ***************************
CLASS lhc_tripincident DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS ValidateAmountField FOR VALIDATE ON SAVE
      IMPORTING keys FOR TripIncident~ValidateAmountField.

    METHODS DetermineTotalExpense FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TripIncident~DetermineTotalExpense.

    METHODS DetermineIncidentStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TripIncident~DetermineIncidentStatus.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR TripIncident RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TripIncident RESULT result.

    METHODS IncidentVerified FOR MODIFY
      IMPORTING keys FOR ACTION TripIncident~IncidentVerified RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TripIncident RESULT result.

ENDCLASS.

CLASS lhc_tripincident IMPLEMENTATION.

  METHOD ValidateAmountField.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_incidents).

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident BY \_TripHeader
        FROM CORRESPONDING #( lt_incidents )
        LINK DATA(lt_link_data).


    " --- Now run the check ---
    LOOP AT lt_incidents INTO DATA(ls_incidents).

      " Clear the messages for state area
      APPEND VALUE #( %tky = ls_incidents-%tky %state_area = 'VALIDATE_AMOUNT' ) TO reported-tripincident.

      IF ls_incidents-IncidentAmount < 0.
        APPEND VALUE #( %tky = ls_incidents-%tky ) TO failed-tripincident.
        APPEND VALUE #( %tky            = ls_incidents-%tky
                        %state_area = 'VALIDATE_AMOUNT'
                        " %path tells to which TRIPID the current incident id is related, so that message can be shown in UI
                        %path           = VALUE #( tripheader-%tky = lt_link_data[ KEY id source-%tky = ls_incidents-%tky ]-target-%tky )
                        %msg            = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '005'
                          severity = if_abap_behv_message=>severity-error )
                        %element-IncidentAmount = if_abap_behv=>mk-on
                      ) TO reported-tripincident.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD DetermineTotalExpense.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident BY \_TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        LINK DATA(lt_parent_links).

    DATA: lt_parent_keys TYPE TABLE FOR READ IMPORT ZI_TripHeader\\TripHeader.

    IF lt_parent_links IS NOT INITIAL.

      lt_parent_keys = VALUE #(
                            FOR ls_link IN lt_parent_links
                            ( %tky = ls_link-target-%tky )
                          ).
    ELSE.
      lt_parent_keys = VALUE #(
                            FOR ls_key IN keys
                            ( %tky-TripID = ls_key-%tky-TripID
                              %tky-%is_draft = if_abap_behv=>mk-on
                             )
                          ).
    ENDIF.

    CHECK lt_parent_keys IS NOT INITIAL.

    " For each affected parent, read ALL its incidents and sum the amounts.
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
      ENTITY TripHeader BY \_Incident
      FIELDS ( IncidentAmount )
      WITH CORRESPONDING #( lt_parent_keys )
      RESULT DATA(lt_all_incidents).

    " Group and sum the incident amounts per parent.
    DATA: lt_update TYPE TABLE FOR UPDATE ZI_TripHeader\\TripHeader.

    LOOP AT lt_parent_keys INTO DATA(ls_parent).

      DATA(lv_total) = REDUCE ztab_tripheader-t_tot_exp(
                         INIT sum = CONV ztab_tripheader-t_tot_exp( 0 )
                         FOR ls_inc IN lt_all_incidents
                           WHERE ( TripID = ls_parent-%tky-TripID )
                         NEXT sum = sum + ls_inc-IncidentAmount
                       ).

      APPEND VALUE #(
        %tky                       = ls_parent-%tky
        TripTotalExpense           = lv_total
        %control-TripTotalExpense  = if_abap_behv=>mk-on
      ) TO lt_update.

    ENDLOOP.

    DELETE ADJACENT DUPLICATES FROM lt_update COMPARING %tky.

    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
    ENTITY TripHeader
      UPDATE FIELDS ( TripTotalExpense )
      WITH lt_update
    REPORTED DATA(lt_reported_update)
    FAILED   DATA(lt_failed_update)
    MAPPED   DATA(lt_mapped_update).

  ENDMETHOD.

  METHOD DetermineIncidentStatus.

    " Read incidents records
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
       RESULT DATA(lt_incidents).

    DATA :lt_update TYPE TABLE FOR UPDATE ZI_TripHeader\\TripIncident.

    LOOP AT lt_incidents INTO DATA(ls_incident).

      APPEND VALUE #(
          %tky = ls_incident-%tky
          ReceiptStatus = COND #( WHEN ls_incident-IncidentCategory = 'BRKD'
                                    OR ls_incident-IncidentCategory = 'ABND'
                                    OR ls_incident-IncidentCategory = 'ACDT'
                                      THEN 'In-Progress'
                                  ELSE 'Not-Verified'
                                )
       ) TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        UPDATE
        FIELDS ( ReceiptStatus )
        WITH lt_update
      REPORTED DATA(lt_reported).

  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD IncidentVerified.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
     RESULT DATA(lt_incident).

    DATA : lt_update  TYPE TABLE FOR UPDATE ZI_TripHeader\\TripIncident.

    LOOP AT lt_incident ASSIGNING FIELD-SYMBOL(<ls_incident>).
      APPEND VALUE #( %tky = <ls_incident>-%tky
                      ReceiptStatus = COND #( WHEN <ls_incident>-IncidentCategory = 'BRKD'
                                                OR <ls_incident>-IncidentCategory = 'ACDT'
                                                  THEN 'Completed'
                                              ELSE 'Verified'
                                            )
                    ) TO lt_update.
    ENDLOOP.

    " Change the status in the transaction buffer
    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        UPDATE FIELDS ( ReceiptStatus )
        WITH lt_update
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
    RESULT lt_incident.

    result = VALUE #( FOR ls_incident IN lt_incident
                        ( %tky = ls_incident-%tky
                          %param = ls_incident )
                    ).

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripIncident
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result
                        ( %tky = ls_result-%tky
                          %action-IncidentVerified = COND #( WHEN ls_result-ReceiptStatus = 'Completed'
                                                               OR ls_result-ReceiptStatus = 'Verified'
                                                                THEN if_abap_behv=>fc-o-disabled
                                                             ELSE if_abap_behv=>fc-o-enabled ) )
                    ).

  ENDMETHOD.

ENDCLASS.

******************* TriHeader - handler Class **************************
CLASS lhc_TripHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR TripHeader RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TripHeader RESULT result.

    METHODS FillDriverDetails FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TripHeader~FillDriverDetails.

    METHODS ValidateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR TripHeader~ValidateMandatoryFields.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TripHeader RESULT result.

    METHODS StartTrip FOR MODIFY
      IMPORTING keys FOR ACTION TripHeader~StartTrip RESULT result.

    METHODS SetDefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TripHeader~SetDefaultStatus.

*    METHODS CancelTrip FOR MODIFY
*      IMPORTING keys FOR ACTION TripHeader~CancelTrip RESULT result.

    METHODS Unlock FOR MODIFY
      IMPORTING keys FOR ACTION TripHeader~Unlock RESULT result.

    METHODS Settle FOR MODIFY
      IMPORTING keys FOR ACTION TripHeader~Settle RESULT result.

    METHODS AddNewLocation FOR MODIFY
      IMPORTING keys FOR ACTION TripHeader~AddNewLocation RESULT result.

    METHODS fillPlaceDescriptions FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TripHeader~fillPlaceDescriptions.

    METHODS EmergencyLockdown FOR MODIFY
      IMPORTING keys FOR ACTION TripHeader~EmergencyLockdown RESULT result.

    METHODS FillTripDate FOR DETERMINE ON SAVE
      IMPORTING keys FOR TripHeader~FillTripDate.

ENDCLASS.

CLASS lhc_TripHeader IMPLEMENTATION.

  METHOD get_instance_authorizations.

    " 1. Perform authorization checks
    AUTHORITY-CHECK OBJECT 'ZDISPTCH_A' ID 'ACTVT' FIELD 'A5'.
    DATA(lv_auth_unlock) = xsdbool( sy-subrc = 0 ).

    AUTHORITY-CHECK OBJECT 'ZDISPTCH_A' ID 'ACTVT' FIELD 'A7'.
    DATA(lv_auth_settle) = xsdbool( sy-subrc = 0 ).

    " 2. Read entities to evaluate state conditions
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
      ENTITY TripHeader
      FIELDS ( TripStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_trips).


    LOOP AT lt_trips INTO DATA(ls_trip).
      result = VALUE #( BASE result
                        ( %tky = ls_trip-%tky
                          %action-Unlock = COND #( WHEN lv_auth_unlock = abap_true AND ls_trip-TripStatus = 'Locked'
                                                      THEN if_abap_behv=>fc-o-enabled
                                                   ELSE if_abap_behv=>fc-o-disabled
                                                 )
                          %action-Settle = COND #( WHEN lv_auth_settle = abap_true AND ls_trip-TripStatus = 'Settled'
                                                      THEN if_abap_behv=>fc-o-enabled
                                                   ELSE if_abap_behv=>fc-o-disabled
                                                 )
                         )
                      ).
    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.

    IF requested_authorizations-%action-Settle = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZDISPTCH_A' ID 'ACTVT' FIELD 'A7'.

      IF sy-subrc = 0.
        result-%action-Settle = IF_ABAP_behv=>auth-allowed.
      ELSE.
        result-%action-Settle = IF_ABAP_behv=>auth-unauthorized.
      ENDIF.
    ENDIF.

    IF requested_authorizations-%action-Unlock = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZDISPTCH_A' ID 'ACTVT' FIELD 'A5'.

      IF sy-subrc = 0.
        result-%action-Unlock = IF_ABAP_behv=>auth-allowed.
      ELSE.
        result-%action-Unlock = IF_ABAP_behv=>auth-unauthorized.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD FillDriverDetails.

*    Read the vehicle number from the transaction buffer
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_trips).

    " 2. Extract unique Vehicle Numbers to avoid redundant DB hits
    DATA(lt_vehicle_query) = lt_trips.
    DELETE lt_vehicle_query WHERE VehicleNumber IS INITIAL.
    SORT lt_vehicle_query BY VehicleNumber.
    DELETE ADJACENT DUPLICATES FROM lt_vehicle_query COMPARING VehicleNumber.

    CHECK lt_vehicle_query IS NOT INITIAL.

    " 3. Bulk Select: Fetch all relevant driver data in one single database call
    SELECT
      FROM ztab_vehicle
      FIELDS v_reg_no, d_id
      FOR ALL ENTRIES IN @lt_vehicle_query
      WHERE v_reg_no = @lt_vehicle_query-VehicleNumber
      INTO TABLE @DATA(lt_v_driver).

    SELECT FROM ztab_driver
        FIELDS d_id, d_full_name, d_mobile
        INTO TABLE @DATA(lt_driver_details).

    DATA: lt_update TYPE TABLE FOR UPDATE ZI_TripHeader.

    LOOP AT lt_trips ASSIGNING FIELD-SYMBOL(<ls_trips>).
      " Find the matching master data in our local buffer
      IF line_exists( lt_v_driver[ v_reg_no = <ls_trips>-VehicleNumber ] )
            AND lt_v_driver[ v_reg_no = <ls_trips>-VehicleNumber ]-d_id IS NOT INITIAL
            AND lt_v_driver[ v_reg_no = <ls_trips>-VehicleNumber ]-d_id NE <ls_trips>-DriverID.

        DATA(driverid) = lt_v_driver[ v_reg_no = <ls_trips>-VehicleNumber ]-d_id.
        DATA(drivername) = lt_driver_details[ d_id = driverid ]-d_full_name.
        DATA(drivermobile) = lt_driver_details[ d_id = driverid ]-d_mobile.

        MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
            ENTITY TripHeader
            UPDATE FIELDS ( DriverID )
            WITH VALUE #( ( %tky         = <ls_trips>-%tky
                            DriverID     = driverid
*                            DriverName = drivername
*                            DriverMobile = drivermobile
                            %control-DriverID = if_abap_behv=>mk-on
*                            %control-DriverName = if_abap_behv=>mk-on
*                            %control-DriverMobile = if_abap_behv=>mk-on
                          )
                        ).
      ELSEIF lt_v_driver[ v_reg_no = <ls_trips>-VehicleNumber ]-d_id IS INITIAL. " Driver not assigned to vehicle
        APPEND VALUE #(
            %tky = <ls_trips>-%tky
            %element-VehicleNumber = if_abap_behv=>mk-on
            %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text = 'Driver not assigned for the vehicle' )
        ) TO reported-tripheader.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD ValidateMandatoryFields.

    READ ENTITIES OF zi_tripheader IN LOCAL MODE
    ENTITY TripHeader
      FIELDS ( VehicleNumber StartPlace EndPlace LoadType Weight WeightUnit RatePerUnit Currency  )
      WITH CORRESPONDING #( keys )
    RESULT DATA(trips).

    LOOP AT trips INTO DATA(trip).

      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_VEHICLE'     ) TO reported-tripheader.
      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_SOURCE'      ) TO reported-tripheader.
      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_DESTINATION' ) TO reported-tripheader.
      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_LOADTYPE'    ) TO reported-tripheader.
      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_WEIGHT'    ) TO reported-tripheader.
      APPEND VALUE #( %tky = trip-%tky %state_area = 'VALIDATE_RATEPERUNIT'    ) TO reported-tripheader.

      " Check vehicle number
      IF trip-VehicleNumber IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_VEHICLE'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '001'
                          severity = if_abap_behv_message=>severity-error )
                        %element-VehicleNumber = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

      " Check source
      IF trip-StartPlace IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_SOURCE'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '002'
                          severity = if_abap_behv_message=>severity-error )
                        %element-StartPlace = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

      " Check destination
      IF trip-EndPlace IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_DESTINATION'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '003'
                          severity = if_abap_behv_message=>severity-error )
                        %element-EndPlace = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

      " Check load type
      IF trip-LoadType IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_LOADTYPE'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '004'
                          severity = if_abap_behv_message=>severity-error )
                        %element-LoadType = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

      " Check Weight / UoM
      IF trip-Weight IS INITIAL OR trip-WeightUnit IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_WEIGHT'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '009'
                          severity = if_abap_behv_message=>severity-error )
                        %element-weight = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

      " Check Rate per unit / Currency
      IF trip-RatePerUnit IS INITIAL OR trip-Currency IS INITIAL.
        APPEND VALUE #( %tky = trip-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = trip-%tky
                        %state_area = 'VALIDATE_RATEPERUNIT'
                        %msg = new_message(
                          id       = 'ZDISPATCH_MSGS'
                          number   = '010'
                          severity = if_abap_behv_message=>severity-error )
                        %element-rateperunit = if_abap_behv=>mk-on
                      ) TO reported-tripheader.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
    ENTITY TripHeader
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_trips).

    " 2. Read Child Incidents to check for Categories
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
    ENTITY TripHeader BY \_Incident
        FIELDS ( IncidentCategory ReceiptStatus ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_incidents)
        LINK DATA(lt_links).

    result = VALUE #(
                        FOR ls_trip IN lt_trips
                        " --- Evaluate Child Condition Inline ---
                        LET lv_can_lockdown = REDUCE abap_boolean(
                                                INIT flag = abap_false
                                                FOR ls_link IN lt_links WHERE ( source-%tky = ls_trip-%tky )
                                                    NEXT flag = COND #( WHEN flag = abap_true
                                                                          THEN abap_true
                                                                        WHEN lt_incidents[ KEY id %tky = ls_link-target-%tky ]-IncidentCategory IS NOT INITIAL
                                                                         AND ( lt_incidents[ KEY id %tky = ls_link-target-%tky ]-IncidentCategory = 'ACDT'
                                                                               OR lt_incidents[ KEY id %tky = ls_link-target-%tky ]-IncidentCategory = 'BRKD'
                                                                               OR lt_incidents[ KEY id %tky = ls_link-target-%tky ]-IncidentCategory = 'ABND' )
                                                                         AND lt_incidents[ KEY id %tky = ls_link-target-%tky ]-ReceiptStatus = 'In-Progress'
                                                                          THEN abap_true
                                                                        ELSE abap_false
                                                                      )
                                              )
                        IN
                        (
                            %tky = ls_trip-%tky

*                            " --- Field Controls (Freeze upon Settled or Locked) ---
*                            %field-Weight      = COND #( WHEN ls_trip-TripStatus = 'Settled' OR ls_trip-TripStatus = 'Locked'
*                                                         THEN if_abap_behv=>fc-f-read_only
*                                                         ELSE if_abap_behv=>fc-f-mandatory )
*
*                            %field-WeightUnit  = COND #( WHEN ls_trip-TripStatus = 'Settled' OR ls_trip-TripStatus = 'Locked'
*                                                         THEN if_abap_behv=>fc-f-read_only
*                                                         ELSE if_abap_behv=>fc-f-mandatory )
*
*                            %field-RatePerUnit = COND #( WHEN ls_trip-TripStatus = 'Settled' OR ls_trip-TripStatus = 'Locked'
*                                                         THEN if_abap_behv=>fc-f-read_only
*                                                         ELSE if_abap_behv=>fc-f-mandatory )
*
*                            %field-Currency    = COND #( WHEN ls_trip-TripStatus = 'Settled' OR ls_trip-TripStatus = 'Locked'
*                                                         THEN if_abap_behv=>fc-f-read_only
*                                                         ELSE if_abap_behv=>fc-f-mandatory )

                            %action-StartTrip = COND #( WHEN ls_trip-TripStatus = 'Planned'
                                                          OR ls_trip-TripStatus = 'Un-Locked'
                                                            THEN if_abap_behv=>fc-o-enabled
                                                        ELSE if_abap_behv=>fc-o-disabled
                                                      )

                            %action-Unlock = COND #( WHEN ls_trip-TripStatus = 'Locked'
                                                            THEN if_abap_behv=>fc-o-enabled
                                                           ELSE  if_abap_behv=>fc-o-disabled
                                                      )

                            %action-Settle = COND #( WHEN ls_trip-TripStatus = 'Settled'
                                                       OR ls_trip-TripStatus = 'Locked'
                                                            THEN if_abap_behv=>fc-o-disabled
                                                     ELSE  if_abap_behv=>fc-o-enabled
                                                   )

                            %action-EmergencyLockdown = COND #( WHEN lv_can_lockdown AND ls_trip-TripStatus NE 'Locked'
                                                                    THEN if_abap_behv=>fc-o-enabled
                                                                ELSE if_abap_behv=>fc-o-disabled
                                                              )

                            %action-Edit = COND #( WHEN ls_trip-TripStatus = 'Locked'
                                                    OR ls_trip-TripStatus = 'Settled'
                                                    THEN if_abap_behv=>fc-o-disabled
                                                   ELSE if_abap_behv=>fc-o-enabled
                                                 ) " <---- This disables the edit button in the draft mode

                            %delete = COND #( WHEN ls_trip-TripStatus = 'In-Transit'
                                                OR ls_trip-TripStatus = 'Settled'
                                                OR ls_trip-TripStatus = 'Locked'
                                                THEN if_abap_behv=>fc-o-disabled
                                              ELSE  if_abap_behv=>fc-o-enabled
                                          )

                           %action-AddNewLocation = COND #( WHEN ls_trip-TripStatus = 'Settled'
                                                                THEN if_abap_behv=>fc-o-disabled
                                                            ELSE if_abap_behv=>fc-o-enabled
                                                          )
                        )
                    ).

  ENDMETHOD.

  METHOD StartTrip.


    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader FIELDS ( TripStatus )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_trips).

    DATA lt_valid_keys LIKE keys.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_trip) = VALUE #( lt_trips[ KEY id %tky = ls_key-%tky ] OPTIONAL ).

      IF ls_trip-TripStatus <> 'Planned' AND ls_trip-TripStatus <> 'Un-Locked'.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message(
                                 id       = 'ZDISPATCH_MSGS'
                                 number   = '011'   " Trip cannot be started in its current status
                                 severity = if_abap_behv_message=>severity-error )
                      ) TO reported-tripheader.
        CONTINUE.
      ENDIF.

      APPEND ls_key TO lt_valid_keys.
    ENDLOOP.

    CHECK lt_valid_keys IS NOT INITIAL.

    " Change the status in the transaction buffer
    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        UPDATE FIELDS ( TripStatus )
        WITH VALUE #( FOR ls_v IN lt_valid_keys
                      ( %tky = ls_key-%tky
                        TripStatus = 'In-Transit' ) )
        FAILED failed
        REPORTED reported.

    " read the records that are modified
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    " Send as result to update the UI
    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.

  METHOD SetDefaultStatus.

    " Update the Trip Status for all newly created records in the buffer
    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
      ENTITY TripHeader
        UPDATE FIELDS ( TripStatus )
        WITH VALUE #( FOR ls_key IN keys
                      ( %tky       = ls_key-%tky
                        TripStatus = 'Planned' ) ).

  ENDMETHOD.

  METHOD Unlock.

    " Restore the stored status
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
      ENTITY TripHeader
        FIELDS ( TripStatus PreviousStatus ReviewReason )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_trips).

    LOOP AT lt_trips ASSIGNING FIELD-SYMBOL(<fs_trip>).

      IF <fs_trip>-TripStatus EQ 'Locked'.
        " Determine previous status to restore (fallback to default if initial)
        DATA(lv_target_status) = COND #( WHEN <fs_trip>-PreviousStatus IS NOT INITIAL
                                            THEN <fs_trip>-PreviousStatus
                                         ELSE 'Planned' ). " Default active status

        " Change the status in the transaction buffer
        MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
            ENTITY TripHeader
            UPDATE FIELDS ( TripStatus PreviousStatus )
            WITH VALUE #( FOR ls_key IN keys
                          ( %tky = ls_key-%tky
                            TripStatus = lv_target_status
                            PreviousStatus = '' ) )
            FAILED failed
            REPORTED reported.
      ELSE. " return error message
        APPEND VALUE #( %tky = <fs_trip>-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = <fs_trip>-%tky
                        %msg = new_message( id       = 'ZDISPATCH_MSGS'
                                           number   = '012'
                                           severity = if_abap_behv_message=>severity-error ) )
          TO reported-tripheader.
      ENDIF.

    ENDLOOP.

    " read the records that are modified
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    " Send as result to update the UI
    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.

  METHOD Settle.

    " Read required settlement fields
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        FIELDS ( DriverID Weight RatePerUnit Currency WeightUnit TripTotalExpense TripStatus )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_trips).

    DATA: lt_update TYPE TABLE FOR UPDATE ZI_TripHeader\\TripHeader.

    LOOP AT lt_trips ASSIGNING FIELD-SYMBOL(<fs_trip>).

      " Check the current state of the trip
      IF <fs_trip>-TripStatus EQ 'In-Transit'.

        APPEND VALUE #( %tky = <fs_trip>-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = <fs_trip>-%tky
                        %msg = new_message( id       = 'ZDISPATCH_MSGS'
                                           number   = '012'
                                           severity = if_abap_behv_message=>severity-error ) )
          TO reported-tripheader.
        CONTINUE.
      ENDIF.

      " Fetch Driver Commission %
      SELECT SINGLE d_comm_pct
        FROM ztab_driver
        WHERE d_id = @<fs_trip>-DriverID
        INTO @DATA(lv_comm_pct).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <fs_trip>-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = <fs_trip>-%tky
                        %msg = new_message( id       = 'ZDISPATCH_MSGS'
                                           number   = '008'
                                           v1       = <fs_trip>-DriverID
                                           severity = if_abap_behv_message=>severity-error ) )
          TO reported-tripheader.
        CONTINUE.
      ENDIF.

      " Perform Financial Calculations
      " Freight = Weight * Rate
      DATA(lv_freight_amt) = CONV ztab_tripheader-t_freight_amt( <fs_trip>-Weight * <fs_trip>-RatePerUnit ).

      " Driver Commission = Freight * (Comm % / 100)
      DATA(lv_comm_amt)    = CONV ztab_tripheader-t_comm_amt( lv_freight_amt * ( lv_comm_pct / 100 ) ).

      " Net Profit = Freight - Commission - Expenses
      DATA(lv_profit_amt)  = CONV ztab_tripheader-t_profit_amt( lv_freight_amt - lv_comm_amt - <fs_trip>-TripTotalExpense ).

      " Append update record
      APPEND VALUE #(
          %tky             = <fs_trip>-%tky
          TripStatus       = 'Settled'
          FreightAmount    = lv_freight_amt
          DriverCommission = lv_comm_amt
          NetProfit        = lv_profit_amt
          %control-TripStatus       = if_abap_behv=>mk-on
          %control-FreightAmount    = if_abap_behv=>mk-on
          %control-DriverCommission = if_abap_behv=>mk-on
          %control-NetProfit        = if_abap_behv=>mk-on
      ) TO lt_update.

    ENDLOOP.

    " 6. Apply updates to transaction buffer
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
          ENTITY TripHeader
          UPDATE FIELDS ( TripStatus FreightAmount DriverCommission NetProfit )
          WITH lt_update
          FAILED failed
          REPORTED reported.
    ENDIF.

*    " Change the status in the transaction buffer
*    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
*        ENTITY TripHeader
*        UPDATE FIELDS ( TripStatus )
*        WITH VALUE #( FOR ls_key IN keys
*                      ( %tky = ls_key-%tky
*                        TripStatus = 'Settled' ) )
*        FAILED failed
*        REPORTED reported.

    " read the records that are modified
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    " Send as result to update the UI
    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.

  METHOD AddNewLocation.

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_location) = ls_key-%param-loc_name.
      DATA(lv_company) = ls_key-%param-comp_name.

      MODIFY ENTITIES OF ZI_Location
          ENTITY LocationBO
          CREATE
          FIELDS ( LocationName CompanyName )
          AUTO FILL CID
          WITH VALUE #( ( LocationName = lv_location
                          CompanyName = lv_company ) )
         MAPPED DATA(lt_mapped)
         FAILED DATA(lt_failed)
         REPORTED DATA(lt_reported).

    ENDLOOP.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_trip).

    result = VALUE #( FOR ls_trip IN lt_trip
                      ( %tky = ls_trip-%tky
                        %param = ls_trip ) ).


  ENDMETHOD.

  METHOD fillPlaceDescriptions.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_trip).

    " Select location details from the location table
    DATA : lt_read_loc TYPE TABLE FOR READ IMPORT ZI_Location\\LocationBO.

    lt_read_loc = VALUE #( FOR ls_trip IN lt_trip WHERE ( SourceID IS NOT INITIAL )
                           ( LocationID = ls_trip-SourceID ) ).

    lt_read_loc = VALUE #( BASE lt_read_loc
                           FOR ls_trip IN lt_trip WHERE ( DestinationID IS NOT INITIAL )
                           ( LocationID = ls_trip-DestinationID ) ).

    DELETE ADJACENT DUPLICATES FROM lt_read_loc COMPARING LocationID.

    CHECK lt_read_loc.

    READ ENTITIES OF ZI_Location
        ENTITY LocationBO
        ALL FIELDS WITH CORRESPONDING #( lt_read_loc )
        RESULT DATA(lt_locations).

*    DATA : lt_update_trip type table for UPDATE ZI_TripHeader\\TripHeader.
    DATA : lv_startplace TYPE ztab_location-l_location,
           lv_endplace   TYPE ztab_location-l_location.

    LOOP AT lt_trip ASSIGNING FIELD-SYMBOL(<ls_trip>).

      " Filling Source description
      lv_startplace = ''.
      IF <ls_trip>-SourceID IS NOT INITIAL
        AND line_exists( lt_locations[  KEY id LocationID = <ls_trip>-SourceID ] ).
        lv_startplace = lt_locations[ KEY id LocationID = <ls_trip>-SourceID ]-LocationName.
      ENDIF.

      "Filling Destination description
      lv_endplace = ''.
      IF <ls_trip>-DestinationID IS NOT INITIAL
        AND line_exists( lt_locations[ KEY id LocationID = <ls_trip>-DestinationID ] ).
        lv_endplace = lt_locations[ KEY id LocationID = <ls_trip>-DestinationID ]-LocationName.
      ENDIF.

      MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
            ENTITY TripHeader
            UPDATE
            FIELDS ( StartPlace EndPlace )
            WITH VALUE #( ( %tky = <ls_trip>-%tky
                            StartPlace = lv_startplace
                            EndPlace = lv_endplace
                            %control-StartPlace = if_abap_behv=>mk-on
                            %control-EndPlace = if_abap_behv=>mk-on
                          )
                        ).

    ENDLOOP.

  ENDMETHOD.

  METHOD EmergencyLockdown.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
    ENTITY TripHeader
      FIELDS ( TripStatus PreviousStatus ReviewReason )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_trips).

    LOOP AT lt_trips ASSIGNING FIELD-SYMBOL(<fs_trip>).
      " Extract the parameter passed from the UI dialog
      DATA(lv_reason) = keys[ KEY id %tky = <fs_trip>-%tky ]-%param-review_reason.

      " 7. Validate empty reason
      IF lv_reason IS INITIAL.
        APPEND VALUE #( %tky = <fs_trip>-%tky ) TO failed-tripheader.
        APPEND VALUE #( %tky = <fs_trip>-%tky
                        %msg = new_message( id       = 'ZDISPATCH_MSGS'
                                           number   = '006'
                                           severity = if_abap_behv_message=>severity-error ) )
          TO reported-tripheader.
        CONTINUE.
      ENDIF.

      " Change the status in the transaction buffer
      MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
          ENTITY TripHeader
          UPDATE FIELDS ( TripStatus ReviewReason PreviousStatus )
          WITH VALUE #( FOR ls_key IN keys
                        ( %tky = ls_key-%tky
                          TripStatus = 'Locked'
                          ReviewReason = lv_reason
                          PreviousStatus = <fs_trip>-TripStatus ) )
          FAILED failed
          REPORTED reported.
    ENDLOOP.

    " Change the status in the transaction buffer
*    MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
*        ENTITY TripHeader
*        UPDATE FIELDS ( TripStatus )
*        WITH VALUE #( FOR ls_key IN keys
*                      ( %tky = ls_key-%tky
*                        TripStatus = 'Locked' ) )
*        FAILED failed
*        REPORTED reported.

    " read the records that are modified
    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    " Send as result to update the UI
    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.

  METHOD FillTripDate.

    READ ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
        FIELDS ( TripDate )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_tripheader).

    " 2. Filter out instances that already have a TripDate set (optional but best practice)
    DELETE lt_tripheader WHERE TripDate IS NOT INITIAL.

    IF lt_tripheader IS NOT INITIAL.
      " 3. Update the TripDate to the current system date (cl_abap_context_info)
      MODIFY ENTITIES OF ZI_TripHeader IN LOCAL MODE
        ENTITY TripHeader
          UPDATE FIELDS ( TripDate )
          WITH VALUE #( FOR ls_header IN lt_tripheader (
                          %tky     = ls_header-%tky
                          TripDate = cl_abap_context_info=>get_system_date( )
                          %control-TripDate = if_abap_behv=>mk-on
                        ) )
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported).

      " 4. Pass any reporting/errors back to the RAP framework if necessary
      reported = CORRESPONDING #( DEEP lt_reported ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

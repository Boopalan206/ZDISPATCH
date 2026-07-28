CLASS zcl_fill_mdata DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
    " Internal table to share Driver IDs across methods
    DATA : mt_drivers   TYPE TABLE OF ztab_driver,
           lt_vehicles  TYPE TABLE OF ztab_vehicle,
           lt_locations TYPE TABLE OF ztab_location,
           lt_trips     TYPE TABLE OF ztab_tripheader,
           lt_items     TYPE TABLE OF ztab_tripitem.

    METHODS clear_all_tables  IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS fill_master_data  IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS fill_trip_data    IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.



CLASS ZCL_FILL_MDATA IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    clear_all_tables( out ).
    fill_master_data( out ). " Generates mt_drivers with UUIDs
*    fill_trip_data( out ).   " Uses mt_drivers to link Trips
  ENDMETHOD.


  METHOD clear_all_tables.
    DELETE FROM ztab_driver.
    DELETE FROM ztab_vehicle.
    DELETE FROM ztab_location.
    DELETE FROM ztab_tripheader.
    DELETE FROM ztab_tripitem.
    out->write( 'All Master and Transactional tables cleared.' ).
  ENDMETHOD.


  METHOD fill_master_data.
    TRY.
        " 1. Prepare Driver Data
        mt_drivers = VALUE #(
          ( d_id = cl_system_uuid=>create_uuid_c36_static( ) d_full_name = 'Magudeswaran' d_mobile = '9876543210' d_emobile = '9876543211'
            d_license = 'TN52 20150001467' d_lexpiry = '20280101' d_govid = 'Aadhar' d_aadhar = '5566778899001122' d_status = 'Active' d_comm_pct = '14.00' )
          ( d_id = cl_system_uuid=>create_uuid_c36_static( ) d_full_name = 'Ragupathi'    d_mobile = '9123456780' d_emobile = '9123456781'
            d_license = 'TN30 20180009921' d_lexpiry = '20300515' d_govid = 'PAN'    d_pan = 'ABCDE1234F'    d_status = 'Active' d_comm_pct = '14.00' )
          ( d_id = cl_system_uuid=>create_uuid_c36_static( ) d_full_name = 'Sivalingam'   d_mobile = '9444012345' d_emobile = '9444012346'
            d_license = 'KA01 20120004321' d_lexpiry = '20271120' d_govid = 'Aadhar' d_aadhar = '1122334455667788' d_status = 'Suspended' d_comm_pct = '14.00' )
          ( d_id = cl_system_uuid=>create_uuid_c36_static( ) d_full_name = 'Karthikeyan'  d_mobile = '9000190002' d_emobile = '9000190003'
            d_license = 'TN37 20160001122' d_lexpiry = '20291010' d_govid = 'Aadhar' d_aadhar = '9988776655443322' d_status = 'Active' d_comm_pct = '14.00' )
          ( d_id = cl_system_uuid=>create_uuid_c36_static( ) d_full_name = 'Vijay Kumar'  d_mobile = '8122334455' d_emobile = '8122334456'
            d_license = 'MH12 20190008877' d_lexpiry = '20320805' d_govid = 'PAN'    d_pan = 'WXYZP5678Q'    d_status = 'Terminated' d_comm_pct = '14.00' )
        ).
      CATCH cx_uuid_error INTO DATA(cx_err).
    ENDTRY.

    INSERT ztab_driver FROM TABLE @mt_drivers.

    " 2. Prepare Vehicle Data (Referencing mt_drivers) as seen in image_df413e.png
    lt_vehicles = VALUE #(
      ( v_reg_no = 'TN52L1467' v_model = '2017-BS-IV' v_capacity = 25 v_status = 'Available'      d_id = mt_drivers[ 1 ]-d_id )
      ( v_reg_no = 'TN52LT468' v_model = '2018-BS-IV' v_capacity = 25 v_status = 'On-Trip'        d_id = mt_drivers[ 2 ]-d_id )
      ( v_reg_no = 'TN30B9921' v_model = '2020-BS-VI' v_capacity = 32 v_status = 'In-Maintenance' d_id = mt_drivers[ 3 ]-d_id )
      ( v_reg_no = 'KA01M1234' v_model = '2019-BS-IV' v_capacity = 20 v_status = 'Available'      d_id = mt_drivers[ 4 ]-d_id )
      ( v_reg_no = 'TN52L5500' v_model = '2022-BS-VI' v_capacity = 40 v_status = 'Available'      d_id = mt_drivers[ 5 ]-d_id )
    ).
    INSERT ztab_vehicle FROM TABLE @lt_vehicles.

    " 3. Prepare Location Data
    lt_locations = VALUE #(
      ( l_id = '8e4b2c1a9d0f3e57' l_location = 'Sriperumbudur' l_company = 'Tata Electronics Private Ltd' )
      ( l_id = '2f9a1c8d7e0b6342' l_location = 'Oragadam'      l_company = 'Renault Nissan Automotive' )
      ( l_id = '5d7e8f1b2a4c9033' l_location = 'Hosur'         l_company = 'TVS Motor Company Ltd' )
      ( l_id = '9b0a3c2d1e7f8455' l_location = 'Guindy'        l_company = 'Amalgamations Group' )
      ( l_id = '1a6c4e2b8d9f0312' l_location = 'Ranipet'       l_company = 'BHEL Ancillaries Unit' )
    ).
    INSERT ztab_location FROM TABLE @lt_locations.

    out->write( 'Master Data (Drivers, Vehicles, Locations) Inserted.' ).
  ENDMETHOD.


  METHOD fill_trip_data.
    GET TIME STAMP FIELD DATA(lv_ts).

    " 1. Trip Header - Mapping Driver 1 and 2 to active trips
    lt_trips = VALUE #(
      ( t_tripid = 'TRIP_001' t_cdate = cl_abap_context_info=>get_system_date( ) t_vno = 'TN52L1467' t_driverid = mt_drivers[ 1 ]-d_id
        t_source = 'Sriperumbudur' t_destination = 'Hosur' t_loadtype = 'FTL' t_status = 'In-Transit' t_tot_exp = 2500
        created_at = lv_ts created_by = sy-uname last_changed_at = lv_ts )
      ( t_tripid = 'TRIP_002' t_cdate = cl_abap_context_info=>get_system_date( ) t_vno = 'TN52LT468' t_driverid = mt_drivers[ 2 ]-d_id
        t_source = 'Oragadam' t_destination = 'Chennai' t_loadtype = 'FTL' t_status = 'Active' t_tot_exp = 1200
        created_at = lv_ts created_by = sy-uname last_changed_at = lv_ts )
    ).
    INSERT ztab_tripheader FROM TABLE @lt_trips.

    TRY.
        " 2. Trip Items (Incidents)
        lt_items = VALUE #(
          ( i_id = cl_system_uuid=>create_uuid_c36_static( ) i_tripid = 'TRIP_001' i_cdate = cl_abap_context_info=>get_system_date( )
            i_categ = 'Fuel' i_descr = 'Refuel at BPCL' i_locn = 'Vellore' i_amount = 2000 i_curr = 'INR' i_rec_status = 'Paid'
            created_at = lv_ts created_by = sy-uname last_changed_at = lv_ts )
          ( i_id = cl_system_uuid=>create_uuid_c36_static( ) i_tripid = 'TRIP_002' i_cdate = cl_abap_context_info=>get_system_date( )
            i_categ = 'Toll' i_descr = 'NH48 Toll' i_locn = 'Sriperumbudur' i_amount = 450 i_curr = 'INR' i_rec_status = 'Paid'
            created_at = lv_ts created_by = sy-uname last_changed_at = lv_ts )
        ).
      CATCH cx_uuid_error INTO DATA(cx_error).
    ENDTRY.
    INSERT ztab_tripitem FROM TABLE @lt_items.

    out->write( 'Transactional Data (Trips & Incidents) Inserted.' ).
  ENDMETHOD.
ENDCLASS.

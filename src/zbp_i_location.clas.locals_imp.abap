CLASS lhc_ZI_Location DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR LocationBO RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR LocationBO RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE LocationBO.

ENDCLASS.

CLASS lhc_ZI_Location IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.

    LOOP AT entities INTO DATA(ls_entity).
      TRY.
        APPEND value #( %cid = ls_entity-%cid
                        locationid = cl_system_uuid=>create_uuid_c36_static( ) ) to mapped-locationbo.
        CATCH cx_uuid_error INTO DATA(uuid_err).
*          APPEND VALUE #(  ) to reported-zi_location.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS zcl_abapgit_tmp_package DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_users TYPE RANGE OF tadir-author.

    CLASS-METHODS is_tmp_package
      IMPORTING
        !iv_package      TYPE devclass
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS is_user_package
      IMPORTING
        !iv_package      TYPE devclass
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS map_package_name
      IMPORTING
        !iv_package       TYPE devclass
      RETURNING
        VALUE(rv_package) TYPE devclass.

    CLASS-METHODS get_user_filter
      IMPORTING
        !iv_package     TYPE devclass
      RETURNING
        VALUE(rt_users) TYPE ty_users.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      c_tmp_package   TYPE devclass VALUE '$TMP',
      c_user_packages TYPE devclass VALUE '$TMP---*'.

ENDCLASS.



CLASS zcl_abapgit_tmp_package IMPLEMENTATION.


  METHOD get_user_filter.

    DATA ls_user LIKE LINE OF rt_users.

    IF is_user_package( iv_package ) = abap_true.
      " Special packages for local user objects filtered by user id
      ls_user-sign   = 'I'.
      ls_user-option = 'EQ'.
      ls_user-low    = iv_package+7(*).
      APPEND ls_user TO rt_users.
    ENDIF.

  ENDMETHOD.


  METHOD is_tmp_package.
    rv_result = boolc( iv_package = c_tmp_package ).
  ENDMETHOD.


  METHOD is_user_package.
    rv_result = boolc( iv_package CP c_user_packages ).
  ENDMETHOD.


  METHOD map_package_name.

    IF is_user_package( iv_package ) = abap_true.
      " Special packages for local user objects (format $TMP---<user_id>) maps to $TMP
      rv_package = c_tmp_package.
    ELSE.
      " Regular package without user filter
      rv_package = iv_package.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

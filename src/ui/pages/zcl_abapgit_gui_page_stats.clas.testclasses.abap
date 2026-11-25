CLASS ltcl_size_format DEFINITION DEFERRED.
CLASS zcl_abapgit_gui_page_stats DEFINITION LOCAL FRIENDS ltcl_size_format.

CLASS ltcl_size_format DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS unit_boundaries FOR TESTING.
    METHODS fractional_sizes FOR TESTING.
    METHODS large_sizes FOR TESTING.
ENDCLASS.

CLASS ltcl_size_format IMPLEMENTATION.
  METHOD unit_boundaries.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 0 )
      exp = '0 Bytes' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1023 )
      exp = '1023 Bytes' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1024 )
      exp = '1.00 KB' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1048576 )
      exp = '1.00 MB' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1073741824 )
      exp = '1.00 GB' ).
  ENDMETHOD.

  METHOD fractional_sizes.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1536 )
      exp = '1.50 KB' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1572864 )
      exp = '1.50 MB' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( 1610612736 )
      exp = '1.50 GB' ).
  ENDMETHOD.

  METHOD large_sizes.
    DATA lv_size TYPE zcl_abapgit_statistics=>ty_size.
    lv_size = '3221225472'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_gui_page_stats=>format_size( lv_size )
      exp = '3.00 GB' ).
  ENDMETHOD.
ENDCLASS.

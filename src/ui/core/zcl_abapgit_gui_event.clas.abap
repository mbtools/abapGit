CLASS zcl_abapgit_gui_event DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_abapgit_gui_event.

    METHODS constructor
      IMPORTING
        !ii_gui_services TYPE REF TO zif_abapgit_gui_services OPTIONAL
        !iv_action       TYPE clike
        !iv_getdata      TYPE clike OPTIONAL
        !it_postdata     TYPE zif_abapgit_html_viewer=>ty_post_data OPTIONAL
        !it_query_table  TYPE zif_abapgit_html_viewer=>ty_query_table OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mo_query TYPE REF TO zcl_abapgit_string_map.
    DATA mo_form_data TYPE REF TO zcl_abapgit_string_map.

    METHODS fields_to_map
      IMPORTING
        !it_fields           TYPE tihttpnvp
      RETURNING
        VALUE(ro_string_map) TYPE REF TO zcl_abapgit_string_map
      RAISING
        zcx_abapgit_exception.
    METHODS query_table_to_map
      IMPORTING
        !it_query_table      TYPE zif_abapgit_html_viewer=>ty_query_table
      RETURNING
        VALUE(ro_string_map) TYPE REF TO zcl_abapgit_string_map
      RAISING
        zcx_abapgit_exception.
ENDCLASS.



CLASS zcl_abapgit_gui_event IMPLEMENTATION.


  METHOD constructor.

    FIELD-SYMBOLS <ls_query_table> LIKE LINE OF it_query_table.

    zif_abapgit_gui_event~mi_gui_services = ii_gui_services.
    zif_abapgit_gui_event~mv_action       = iv_action.
    zif_abapgit_gui_event~mv_getdata      = iv_getdata.
    zif_abapgit_gui_event~mt_postdata     = it_postdata.
    zif_abapgit_gui_event~mt_query_table  = it_query_table.

*    " Action in query data overwrites form action
*    READ TABLE it_query_table ASSIGNING <ls_query_table> WITH KEY name = 'action'.
*    IF sy-subrc = 0.
*      zif_abapgit_gui_event~mv_action = <ls_query_table>-value.
*      REPLACE 'sapevent:' IN zif_abapgit_gui_event~mv_action WITH ''.
*    ENDIF.

    IF ii_gui_services IS BOUND.
      zif_abapgit_gui_event~mv_current_page_name = ii_gui_services->get_current_page_name( ).
    ENDIF.

  ENDMETHOD.


  METHOD fields_to_map.
    FIELD-SYMBOLS <ls_field> LIKE LINE OF it_fields.

    CREATE OBJECT ro_string_map EXPORTING iv_case_insensitive = abap_true.
    LOOP AT it_fields ASSIGNING <ls_field>.
      ro_string_map->set(
        iv_key = <ls_field>-name
        iv_val = <ls_field>-value ).
    ENDLOOP.
  ENDMETHOD.


  METHOD query_table_to_map.
    FIELD-SYMBOLS <ls_field> LIKE LINE OF it_query_table.

    CREATE OBJECT ro_string_map EXPORTING iv_case_insensitive = abap_true.
    LOOP AT it_query_table ASSIGNING <ls_field> WHERE name <> 'action'.
      ro_string_map->set(
        iv_key = |{ <ls_field>-name }|
        iv_val = <ls_field>-value ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_abapgit_gui_event~form_data.

    IF mo_form_data IS NOT BOUND.
*      IF zif_abapgit_gui_event~mt_query_table IS INITIAL OR zif_abapgit_gui_event~mv_action NS 'stage'.
        mo_form_data = fields_to_map(
          zcl_abapgit_html_action_utils=>parse_post_form_data( zif_abapgit_gui_event~mt_postdata ) ).
*      ELSE.
*        mo_form_data = query_table_to_map( zif_abapgit_gui_event~mt_query_table ).
*      ENDIF.
      mo_form_data->freeze( ).
    ENDIF.
    ro_string_map = mo_form_data.

  ENDMETHOD.


  METHOD zif_abapgit_gui_event~query.

    IF mo_query IS NOT BOUND.
      mo_query = fields_to_map(
        zcl_abapgit_html_action_utils=>parse_fields( zif_abapgit_gui_event~mv_getdata ) ).
      mo_query->freeze( ).
    ENDIF.
    ro_string_map = mo_query.

  ENDMETHOD.
ENDCLASS.

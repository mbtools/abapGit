CLASS zcl_abapgit_gui_page_stats DEFINITION
  PUBLIC
  FINAL
  INHERITING FROM zcl_abapgit_gui_component
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_gui_page_title.
    INTERFACES zif_abapgit_gui_event_handler.
    INTERFACES zif_abapgit_gui_menu_provider.
    INTERFACES zif_abapgit_gui_renderable.

    CLASS-METHODS create
      RETURNING VALUE(ri_page) TYPE REF TO zif_abapgit_gui_renderable
      RAISING zcx_abapgit_exception.
    METHODS constructor RAISING zcx_abapgit_exception.

  PRIVATE SECTION.
    DATA ms_snapshot TYPE zcl_abapgit_statistics=>ty_snapshot.
ENDCLASS.



CLASS zcl_abapgit_gui_page_stats IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).
    ms_snapshot = zcl_abapgit_statistics=>read( ).
  ENDMETHOD.


  METHOD create.
    DATA lo_component TYPE REF TO zcl_abapgit_gui_page_stats.
    CREATE OBJECT lo_component.
    ri_page = zcl_abapgit_gui_page_hoc=>create( lo_component ).
  ENDMETHOD.


  METHOD zif_abapgit_gui_event_handler~on_event.
    IF ii_event->mv_action = 'refresh'.
      ms_snapshot = zcl_abapgit_statistics=>refresh( ).
      rs_handled-state = zcl_abapgit_gui=>c_event_state-re_render.
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_gui_menu_provider~get_menu.
    ro_toolbar = zcl_abapgit_html_toolbar=>create( 'toolbar-statistics' )->add(
      iv_txt = 'Refresh'
      iv_act = 'refresh'
    )->add(
      iv_txt = 'Back'
      iv_act = zif_abapgit_definitions=>c_action-go_back ).
  ENDMETHOD.


  METHOD zif_abapgit_gui_page_title~get_page_title.
    rv_title = 'Statistics'.
  ENDMETHOD.


  METHOD zif_abapgit_gui_renderable~render.

    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    DATA lv_online TYPE i.
    DATA lv_offline TYPE i.
    DATA lv_favorites TYPE i.
    DATA lv_protected TYPE i.
    DATA lv_github TYPE i.
    DATA lv_gitlab TYPE i.
    DATA lv_others TYPE i.
    DATA lv_objects TYPE i.
    DATA lv_files TYPE i.
    DATA lv_objects_min TYPE i.
    DATA lv_objects_avg TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_objects_max TYPE i.
    DATA lv_files_min TYPE i.
    DATA lv_files_avg TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_files_max TYPE i.
    DATA lv_size TYPE zcl_abapgit_statistics=>ty_size.
    DATA lv_errors TYPE i.
    DATA lv_type TYPE string.
    DATA lv_status TYPE string.

    register_handlers( ).
    ri_html = zcl_abapgit_html=>create( ).
    ri_html->add( '<div class="repo-overview">' ).
    IF ms_snapshot-refreshed_at IS INITIAL.
      ri_html->add( '<p>No saved statistics. Choose Refresh to serialize all repositories locally.</p>' ).
      ri_html->add( '</div>' ).
      RETURN.
    ENDIF.

    LOOP AT ms_snapshot-repos INTO ls_repo.
      IF sy-tabix = 1 OR ls_repo-objects < lv_objects_min.
        lv_objects_min = ls_repo-objects.
      ENDIF.
      IF ls_repo-objects > lv_objects_max.
        lv_objects_max = ls_repo-objects.
      ENDIF.
      IF sy-tabix = 1 OR ls_repo-files < lv_files_min.
        lv_files_min = ls_repo-files.
      ENDIF.
      IF ls_repo-files > lv_files_max.
        lv_files_max = ls_repo-files.
      ENDIF.
      IF ls_repo-offline = abap_true.
        lv_offline = lv_offline + 1.
      ELSE.
        lv_online = lv_online + 1.
        CASE ls_repo-host.
          WHEN 'GitHub'.
            lv_github = lv_github + 1.
          WHEN 'GitLab'.
            lv_gitlab = lv_gitlab + 1.
          WHEN OTHERS.
            lv_others = lv_others + 1.
        ENDCASE.
      ENDIF.
      IF ls_repo-favorite = abap_true.
        lv_favorites = lv_favorites + 1.
      ENDIF.
      IF ls_repo-write_protected = abap_true.
        lv_protected = lv_protected + 1.
      ENDIF.
      IF ls_repo-error IS NOT INITIAL.
        lv_errors = lv_errors + 1.
      ENDIF.
      lv_objects = lv_objects + ls_repo-objects.
      lv_files = lv_files + ls_repo-files.
      lv_size = lv_size + ls_repo-size.
    ENDLOOP.
    IF ms_snapshot-repos IS NOT INITIAL.
      lv_objects_avg = lv_objects / lines( ms_snapshot-repos ).
      lv_files_avg = lv_files / lines( ms_snapshot-repos ).
    ENDIF.

    ri_html->add( |<p>Last refresh: { ms_snapshot-refreshed_at TIMESTAMP = ISO } UTC</p>| ).
    ri_html->add( '<p>Saved statistics for the current user. Refresh serializes local files without fetching remotes.</p>' ).
    ri_html->add( '<table class="default-table"><tbody>' ).
    ri_html->add( |<tr><th>Total repositories</th><td>{ lines( ms_snapshot-repos ) }</td></tr>| ).
    ri_html->add( |<tr><th>Online repositories</th><td>{ lv_online }</td></tr>| ).
    ri_html->add( |<tr><th>Offline repositories</th><td>{ lv_offline }</td></tr>| ).
    ri_html->add( |<tr><th>Favorites</th><td>{ lv_favorites }</td></tr>| ).
    ri_html->add( |<tr><th>Write protected repositories</th><td>{ lv_protected }</td></tr>| ).
    ri_html->add( |<tr><th>GitHub / GitLab / Others (online)</th>| &&
      |<td>{ lv_github } / { lv_gitlab } / { lv_others }</td></tr>| ).
    ri_html->add( |<tr><th>TADIR objects</th><td>{ lv_objects }</td></tr>| ).
    ri_html->add( |<tr><th>TADIR objects per repo (min / avg / max)</th>| &&
      |<td>{ lv_objects_min } / { lv_objects_avg } / { lv_objects_max }</td></tr>| ).
    ri_html->add( |<tr><th>Local files</th><td>{ lv_files }</td></tr>| ).
    ri_html->add( |<tr><th>Local files per repo (min / avg / max)</th>| &&
      |<td>{ lv_files_min } / { lv_files_avg } / { lv_files_max }</td></tr>| ).
    ri_html->add( |<tr><th>Total file size (bytes)</th><td>{ lv_size }</td></tr>| ).
    ri_html->add( '</tbody></table>' ).
    IF lv_errors > 0.
      ri_html->add( |<p class="attention">{ lv_errors } repositories have errors. | &&
        |Counts may be incomplete; see details below.</p>| ).
    ENDIF.
    ri_html->add( '<p>Hosts classify github.com and gitlab.com; other hosts, '
      && 'including self-hosted services, count as Others.</p>'
      && '<table class="default-table"><thead><tr>' ).
    ri_html->add( '<th>Repository</th><th>Package</th><th>Type</th><th>Host</th>' ).
    ri_html->add( '<th>Favorite</th><th>Write protected</th><th>TADIR objects</th>' ).
    ri_html->add( '<th>Local files</th><th>Size (bytes)</th><th>Status</th></tr></thead><tbody>' ).
    LOOP AT ms_snapshot-repos INTO ls_repo.
      lv_type = 'Online'.
      IF ls_repo-offline = abap_true.
        lv_type = 'Offline'.
      ENDIF.
      lv_status = 'OK'.
      IF ls_repo-error IS NOT INITIAL.
        lv_status = ls_repo-error.
      ENDIF.
      ri_html->add( |<tr><td>{ escape( val = ls_repo-name
                                       format = cl_abap_format=>e_html_text ) }</td>| ).
      ri_html->add( |<td>{ escape( val = ls_repo-package
                                   format = cl_abap_format=>e_html_text ) }</td>| ).
      ri_html->add( |<td>{ lv_type }</td><td>{ ls_repo-host }</td>| ).
      ri_html->add( |<td>{ ls_repo-favorite }</td><td>{ ls_repo-write_protected }</td>| ).
      ri_html->add( |<td>{ ls_repo-objects }</td><td>{ ls_repo-files }</td><td>{ ls_repo-size }</td>| ).
      ri_html->add( |<td>{ escape( val = lv_status
                                   format = cl_abap_format=>e_html_text ) }</td></tr>| ).
    ENDLOOP.
    ri_html->add( '</tbody></table></div>' ).

  ENDMETHOD.
ENDCLASS.

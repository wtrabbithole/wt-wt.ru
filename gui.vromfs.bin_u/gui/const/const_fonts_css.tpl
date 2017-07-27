/*type of layout - pixel or fixed can be set here*/
@const scrn_tgt       : <<scrnTgt>>;
@const pf_outdated    : <<pxFontTgtOutdated>>; /*in this height images are pixel to pixel*/
@const sf: <<scrnTgt>>;
@const pf: 1080; /*smooth pixel size multiplyer, usage: @sf/@pf_outdated */

/* fonts */
@const bold:       small_text<<set>>;
@const small:      small_text<<set>>;//arial_small;
@const tiny:       tiny_text<<set>>;//arial_small;
@const veryTiny:   very_tiny_text<<set>>;//arial_small;
@const normal:     medium_text<<set>>;//arial;
@const big:        big_text<<set>>; //arial_big;
@const smallBold:  small_text<<set>>;//arial_small_b;
@const normalBold: medium_text<<set>>;//arial_b;
@const times_big:  title_text<<set>>;//times_big;
@const optionFont: medium_text<<set>>;
@const symbolFont: small_text<<set>>;
@const title_big: title_text<<set>>; //title_text_hud

/*by usage*/
@const menubutton_font:            medium_text<<set>>;  //arial_big;
@const menubutton_selected_font:   medium_text<<set>>;  //arial_big;
@const dialogbutton_font:          medium_text<<set>>;  //arial;
@const dialogbutton_selected_font: medium_text<<set>>;  //arial;
@const option_font:                small_text<<set>>;
@const option_selected_font:       small_text<<set>>;
@const mis_chapter_font:           medium_text<<set>>;
@const mis_chapter_selected_font:  medium_text<<set>>;
@const mis_item_font:              small_text<<set>>;
@const mis_item_selected_font:     small_text<<set>>;
@const gamertag_font:              tiny_text<<set>>;
@const nav_button_font:            small_text<<set>>;
@const nav_button_pushed_font:     small_text<<set>>;
@const shopItemFont:               tiny_text<<set>>;
@const slotItemFont:               tiny_text<<set>>;

@const kbdFont:                    kbd_text<<set>>;

@const headerFont:                 header_text<<set>>;
@const battleButtonFont:           battle_button_text<<set>>;
@const battleButtonFontNavigation: battle_button_text_navigation<<set>>;

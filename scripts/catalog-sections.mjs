// Curated top-level sections. Raw AppStream/descriptor categories map into this
// fixed set so the catalog filter stays small no matter how many raw categories
// appear. The keys are also the only values catalog.category may take: the
// descriptor audit rejects anything else, since an unmapped value would land
// the app in Utilities without anyone noticing.
// Values are stable slugs, not display text: the section is baked into the JSON
// at build time but rendered in the reader's language, so it has to survive as
// an identifier the site can look up (`section.<slug>`) rather than a string
// that is already English. The client-side category filter matches on this slug
// too, which keeps filtering locale-independent.
export const SECTION_MAP = {
  // AppStream has no category for this one, so `AI` is a FlatPark-only value an
  // app sets in its descriptor's catalog.category. It stays out of the metainfo,
  // where the app keeps a real AppStream category (Development, Office, …) so
  // desktop menus still place it sensibly.
  AI: 'ai',
  Development: 'development', IDE: 'development', Building: 'development',
  Finance: 'finance',
  // The fdo Network main category, under the name every desktop menu gives it:
  // browsers, downloaders, file transfer, chat and remote access all live here.
  Network: 'internet', Communication: 'internet', Chat: 'internet',
  InstantMessaging: 'internet', News: 'internet',
  RemoteAccess: 'internet', FileTransfer: 'internet', P2P: 'internet',
  Science: 'science', Education: 'science', Geoscience: 'science',
  // Mail clients sit with calendars, contacts and documents, not with chat.
  // Flathub labels this section "Productivity", which is not a category of its
  // own: a descriptor says Office.
  Office: 'office', Spreadsheet: 'office', Email: 'office',
  Graphics: 'graphics', Photography: 'graphics',
  AudioVideo: 'audio-video', Audio: 'audio-video', Video: 'audio-video', Player: 'audio-video',
  Game: 'games',
  System: 'system', Settings: 'system', Security: 'system',
  Utility: 'utilities',
};
export const sectionFor = (cat) => SECTION_MAP[cat] || 'utilities';

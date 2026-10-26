// Public registry settings. Both values are safe to commit: the Supabase publishable
// (anon) key is designed to be public, and row-level security (supabase/schema.sql)
// limits it to reading and adding builds.
window.EB_CONFIG = {
  supabaseUrl: '',   // e.g. https://abcdefghijkl.supabase.co
  supabaseKey: ''    // the project's publishable / anon key
};

import { createClient } from "@supabase/supabase-js";

const urlSupabase=import.meta.env.VITE_SUPABASE_URL;
const clavePublica=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

export const supabase = createClient(urlSupabase, clavePublica);
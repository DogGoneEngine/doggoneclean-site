/*
 * Mount Olympus - the one config file.
 *
 * This is the whole control panel for the dashboard. To add a new business
 * (a future project), copy one of the objects in OLYMPUS.buildings, change the
 * fields, and redeploy. Nothing else needs to change. The page builds itself
 * from this file.
 *
 * Field guide for a building:
 *   key      short id, lowercase, no spaces (used for sorting/keys)
 *   name     the display name
 *   tagline  one short line under the name
 *   accent   a hex color that themes the card
 *   live     the public website URL (also pinged for the "reachable" dot)
 *   doors    grouped links. Each group has a label and an array of {label, url}.
 *            Groups render in order. Leave a group out if it does not apply.
 *
 * A door with no url (or url: null) renders as a quiet "not built yet" chip,
 * so the map stays honest about what exists.
 */
window.OLYMPUS = {
  owner: "Paul",

  // Optional one-liners shown under the clock, rotated daily. Keep them short.
  mottos: [
    "Earn more every year while asking less of the people who run it.",
    "Build the moat a smart machine cannot prompt past.",
    "Make it less dumb, delete the part, simplify, accelerate, then automate.",
    "Would this survive a full redesign tomorrow?",
    "Doors open. Walk through the one that matters today.",
  ],

  buildings: [
    {
      key: "clean",
      name: "Dog Gone Clean",
      tagline: "Ocala dog grooming, evolving to no-haircut full dog grooming",
      accent: "#39a0ff",
      live: "https://hurricanebath.com",
      doors: [
        {
          label: "Front of house",
          links: [
            { label: "Website", url: "https://hurricanebath.com" },
            { label: "Booking", url: "https://hurricanebath.com/book" },
            { label: "Client Portal", url: "https://hurricanebath.com/portal" },
            { label: "Tracker", url: "https://hurricanebath.com/track" },
          ],
        },
        {
          label: "Back of house",
          links: [
            { label: "Laelaps (admin)", url: "https://hurricanebath.com/laelaps" },
          ],
        },
        {
          label: "Engine room",
          collapsed: true,
          links: [
            { label: "Supabase", url: "https://supabase.com/dashboard/project/urebdrosrxejhubpbxsa" },
            { label: "GitHub repo", url: "https://github.com/DogGoneEngine/doggoneclean-site" },
            { label: "Deploys (Actions)", url: "https://github.com/DogGoneEngine/doggoneclean-site/actions" },
            { label: "Client source of truth (Drive)", url: "https://drive.google.com/drive/folders/1oTHLDKe6ao-Q39OoudL058PezwXX8lQG" },
          ],
        },
      ],
    },
    {
      key: "nails",
      name: "Dog Gone Nails",
      tagline: "Nails-only, The Villages (Jake's shop)",
      accent: "#b985ff",
      live: "https://doggonenails.com",
      doors: [
        {
          label: "Front of house",
          links: [
            { label: "Website", url: "https://doggonenails.com" },
            { label: "Booking", url: "https://doggonenails.com/book" },
            { label: "Client Portal", url: "https://doggonenails.com/portal" },
          ],
        },
        {
          label: "Back of house",
          links: [
            { label: "Operator (String of Pearls)", url: "https://doggonenails.com/operator" },
            { label: "Orbit (admin)", url: "https://doggonenails.com/orbit" },
          ],
        },
        {
          label: "Engine room",
          collapsed: true,
          links: [
            { label: "Supabase", url: "https://supabase.com/dashboard/project/cxjpfbfudupjffhkkiun" },
            { label: "GitHub repo", url: "https://github.com/DogGoneEngine/doggonenails-site" },
            { label: "Deploys (Actions)", url: "https://github.com/DogGoneEngine/doggonenails-site/actions" },
          ],
        },
      ],
    },

    // To add a future project, copy this template, fill it in, drop the
    // "template: true" line, and redeploy.
    // {
    //   key: "newproject",
    //   name: "New Project",
    //   tagline: "What it is, in one line",
    //   accent: "#d9b46a",
    //   live: "https://example.com",
    //   doors: [
    //     { label: "Front of house", links: [{ label: "Website", url: "https://example.com" }] },
    //   ],
    // },
  ],

  // Cross-cutting tools that are not tied to a single business.
  shelf: [
    { label: "Supabase org", url: "https://supabase.com/dashboard/org/rnswdmikyxxukefcikui" },
    { label: "GitHub (DogGoneEngine)", url: "https://github.com/DogGoneEngine" },
    { label: "DigitalOcean droplet", url: "https://cloud.digitalocean.com/droplets" },
    { label: "Cloudflare DNS", url: "https://dash.cloudflare.com" },
    { label: "GoDaddy domains", url: "https://dcc.godaddy.com/control/portfolio" },
    { label: "Stripe", url: "https://dashboard.stripe.com" },
    { label: "Google Drive", url: "https://drive.google.com/drive/my-drive" },
    { label: "Anthropic console", url: "https://console.anthropic.com" },
  ],
};

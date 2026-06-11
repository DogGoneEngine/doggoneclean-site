// src/components/portal/breeds.js
//
// The breed list is the AUTHORITY in the booking funnel (Paul, 2026-06-11):
// picking the breed sets the coat tier, the client never self-classifies into
// the cheaper tier, and an excluded breed is declined kindly the moment it is
// picked rather than at the door. The free-text path still exists behind
// "Other / not listed" and is still gated by the exclusion regex plus the
// server-side teeth in bath_start_subscription, so this list narrows the
// honest path without becoming the only net.
//
// tier values: 'smoothcoat' | 'doublecoat' | 'excluded'
// The excluded set mirrors excluded_breeds_are_slide_holes exactly (doodles
// and poodle crosses, Siberian Huskies, Great Pyrenees, Great Danes); this
// file never widens or narrows that rule on its own.

export const BREEDS = [
  // Excluded by rule (declined kindly, here and server-side)
  { name: 'Goldendoodle', tier: 'excluded' },
  { name: 'Labradoodle', tier: 'excluded' },
  { name: 'Bernedoodle', tier: 'excluded' },
  { name: 'Aussiedoodle', tier: 'excluded' },
  { name: 'Any doodle or poodle mix', tier: 'excluded' },
  { name: 'Poodle (Standard, Miniature, or Toy)', tier: 'excluded' },
  { name: 'Siberian Husky', tier: 'excluded' },
  { name: 'Great Pyrenees', tier: 'excluded' },
  { name: 'Great Dane', tier: 'excluded' },

  // Smoothcoat: smooth, short coat, quick dry
  { name: 'American Pit Bull Terrier / Staffordshire', tier: 'smoothcoat' },
  { name: 'Basset Hound', tier: 'smoothcoat' },
  { name: 'Beagle', tier: 'smoothcoat' },
  { name: 'Bloodhound', tier: 'smoothcoat' },
  { name: 'Boston Terrier', tier: 'smoothcoat' },
  { name: 'Boxer', tier: 'smoothcoat' },
  { name: 'Bulldog (English)', tier: 'smoothcoat' },
  { name: 'Cane Corso', tier: 'smoothcoat' },
  { name: 'Chihuahua (smooth coat)', tier: 'smoothcoat' },
  { name: 'Coonhound', tier: 'smoothcoat' },
  { name: 'Dachshund (smooth coat)', tier: 'smoothcoat' },
  { name: 'Dalmatian', tier: 'smoothcoat' },
  { name: 'Doberman Pinscher', tier: 'smoothcoat' },
  { name: 'French Bulldog', tier: 'smoothcoat' },
  { name: 'Greyhound', tier: 'smoothcoat' },
  { name: 'Italian Greyhound', tier: 'smoothcoat' },
  { name: 'Jack Russell Terrier', tier: 'smoothcoat' },
  { name: 'Mastiff', tier: 'smoothcoat' },
  { name: 'Miniature Pinscher', tier: 'smoothcoat' },
  { name: 'Pointer', tier: 'smoothcoat' },
  { name: 'Pug', tier: 'smoothcoat' },
  { name: 'Rat Terrier', tier: 'smoothcoat' },
  { name: 'Rhodesian Ridgeback', tier: 'smoothcoat' },
  { name: 'Rottweiler', tier: 'smoothcoat' },
  { name: 'Vizsla', tier: 'smoothcoat' },
  { name: 'Weimaraner', tier: 'smoothcoat' },
  { name: 'Whippet', tier: 'smoothcoat' },

  // Doublecoat: thick or heavy-shedding coat, longer dry, priced for it
  { name: 'Akita', tier: 'doublecoat' },
  { name: 'Australian Cattle Dog', tier: 'doublecoat' },
  { name: 'Australian Shepherd', tier: 'doublecoat' },
  { name: 'Bernese Mountain Dog', tier: 'doublecoat' },
  { name: 'Border Collie', tier: 'doublecoat' },
  { name: 'Cavalier King Charles Spaniel', tier: 'doublecoat' },
  { name: 'Chow Chow', tier: 'doublecoat' },
  { name: 'Cocker Spaniel', tier: 'doublecoat' },
  { name: 'Collie', tier: 'doublecoat' },
  { name: 'Corgi (Pembroke or Cardigan)', tier: 'doublecoat' },
  { name: 'German Shepherd', tier: 'doublecoat' },
  { name: 'Golden Retriever', tier: 'doublecoat' },
  { name: 'Labrador Retriever', tier: 'doublecoat' },
  { name: 'Newfoundland', tier: 'doublecoat' },
  { name: 'Pomeranian', tier: 'doublecoat' },
  { name: 'Saint Bernard', tier: 'doublecoat' },
  { name: 'Samoyed', tier: 'doublecoat' },
  { name: 'Sheltie (Shetland Sheepdog)', tier: 'doublecoat' },
  { name: 'Shiba Inu', tier: 'doublecoat' },
  { name: 'Springer Spaniel', tier: 'doublecoat' },
];

export const TIER_LABEL = { smoothcoat: 'Smoothcoat', doublecoat: 'Doublecoat' };

export function breedByName(name) {
  return BREEDS.find((b) => b.name === name) || null;
}

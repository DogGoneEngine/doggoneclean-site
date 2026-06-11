// src/components/portal/breeds.js
//
// The breed list is the AUTHORITY in the booking funnel (Paul, 2026-06-11):
// picking the breed sets the coat tier, the client never self-classifies into
// the cheaper tier, and an excluded breed is declined kindly the moment it is
// picked rather than at the door. The dropdown shows the breeds common around
// here first, then everything else A to Z, so a Golden owner never scrolls
// past 90 rare breeds; "Mixed breed" and "Other / not listed" catch the rest,
// still gated by the exclusion regex here and bath_start_subscription server
// side.
//
// Tier principle (Paul, 2026-06-11): the tier is about the WORK, not the
// textbook. A Lab is technically double-coated but grooms like a smoothcoat,
// so it books smoothcoat. Exclusions, three kinds, each with its own kind
// decline: 'haircut' (coats that need haircut-level dog grooming: doodles,
// poodles, Shih Tzus, Pomeranians and friends; no-haircut dogs are the whole
// point), 'coat' (excessive double coats: Husky, Malamute, Samoyed, Chow),
// and 'size' (excessively large dogs: Great Dane, Saint Bernard,
// Newfoundland and friends; a route stop has to get in and out).
//
// tier values: 'smoothcoat' | 'doublecoat' | 'excluded' (with reason)

export const BREEDS = [
  // ── Common around here (shown first, in this order) ──────────────
  { name: 'Labrador Retriever', tier: 'smoothcoat', common: 1 },
  { name: 'Golden Retriever', tier: 'doublecoat', common: 2 },
  { name: 'Goldendoodle', tier: 'excluded', reason: 'haircut', common: 3 },
  { name: 'German Shepherd', tier: 'doublecoat', common: 4 },
  { name: 'Australian Shepherd', tier: 'doublecoat', common: 5 },
  { name: 'Cavalier King Charles Spaniel', tier: 'doublecoat', common: 6 },
  { name: 'American Pit Bull Terrier / Staffordshire', tier: 'smoothcoat', common: 7 },
  { name: 'French Bulldog', tier: 'smoothcoat', common: 8 },
  { name: 'Chihuahua', tier: 'smoothcoat', common: 9 },
  { name: 'Dachshund', tier: 'smoothcoat', common: 10 },
  { name: 'Beagle', tier: 'smoothcoat', common: 11 },
  { name: 'Corgi (Pembroke or Cardigan)', tier: 'doublecoat', common: 12 },
  { name: 'Shih Tzu', tier: 'excluded', reason: 'haircut', common: 13 },
  { name: 'Yorkshire Terrier (Yorkie)', tier: 'excluded', reason: 'haircut', common: 14 },
  { name: 'Maltese', tier: 'excluded', reason: 'haircut', common: 15 },
  { name: 'Boxer', tier: 'smoothcoat', common: 16 },

  // ── Everything else, A to Z in the dropdown ───────────────────────
  // Smoothcoat: short or work-light coats, the quicker visit
  { name: 'American Bulldog', tier: 'smoothcoat' },
  { name: 'Basenji', tier: 'smoothcoat' },
  { name: 'Basset Hound', tier: 'smoothcoat' },
  { name: 'Belgian Malinois', tier: 'smoothcoat' },
  { name: 'Bloodhound', tier: 'smoothcoat' },
  { name: 'Boston Terrier', tier: 'smoothcoat' },
  { name: 'Brittany', tier: 'smoothcoat' },
  { name: 'Bulldog (English)', tier: 'smoothcoat' },
  { name: 'Bull Terrier', tier: 'smoothcoat' },
  { name: 'Cairn Terrier', tier: 'smoothcoat' },
  { name: 'Cane Corso', tier: 'smoothcoat' },
  { name: 'Catahoula Leopard Dog', tier: 'smoothcoat' },
  { name: 'Chesapeake Bay Retriever', tier: 'smoothcoat' },
  { name: 'Chinese Crested', tier: 'smoothcoat' },
  { name: 'Coonhound', tier: 'smoothcoat' },
  { name: 'Dalmatian', tier: 'smoothcoat' },
  { name: 'Doberman Pinscher', tier: 'smoothcoat' },
  { name: 'German Shorthaired Pointer', tier: 'smoothcoat' },
  { name: 'Greyhound', tier: 'smoothcoat' },
  { name: 'Italian Greyhound', tier: 'smoothcoat' },
  { name: 'Jack Russell Terrier', tier: 'smoothcoat' },
  { name: 'Miniature Pinscher', tier: 'smoothcoat' },
  { name: 'Papillon', tier: 'smoothcoat' },
  { name: 'Plott Hound', tier: 'smoothcoat' },
  { name: 'Pointer', tier: 'smoothcoat' },
  { name: 'Pug', tier: 'smoothcoat' },
  { name: 'Rat Terrier', tier: 'smoothcoat' },
  { name: 'Rhodesian Ridgeback', tier: 'smoothcoat' },
  { name: 'Rottweiler', tier: 'smoothcoat' },
  { name: 'Vizsla', tier: 'smoothcoat' },
  { name: 'Weimaraner', tier: 'smoothcoat' },
  { name: 'Whippet', tier: 'smoothcoat' },

  // Doublecoat: a real deshed, the longer visit, priced for it
  { name: 'Australian Cattle Dog (Heeler)', tier: 'doublecoat' },
  { name: 'Border Collie', tier: 'doublecoat' },
  { name: 'Boykin Spaniel', tier: 'doublecoat' },
  { name: 'Collie (Rough or Smooth)', tier: 'doublecoat' },
  { name: 'English Setter', tier: 'doublecoat' },
  { name: 'Flat-Coated Retriever', tier: 'doublecoat' },
  { name: 'Irish Setter', tier: 'doublecoat' },
  { name: 'Sheltie (Shetland Sheepdog)', tier: 'doublecoat' },
  { name: 'Shiba Inu', tier: 'doublecoat' },
  { name: 'Springer Spaniel', tier: 'doublecoat' },

  // Excluded: haircut-level coats (no-haircut dogs are the whole point)
  { name: 'Airedale Terrier', tier: 'excluded', reason: 'haircut' },
  { name: 'Any doodle or poodle mix', tier: 'excluded', reason: 'haircut' },
  { name: 'Aussiedoodle', tier: 'excluded', reason: 'haircut' },
  { name: 'Bernedoodle', tier: 'excluded', reason: 'haircut' },
  { name: 'Bichon Frise', tier: 'excluded', reason: 'haircut' },
  { name: 'Bouvier des Flandres', tier: 'excluded', reason: 'haircut' },
  { name: 'Cavapoo', tier: 'excluded', reason: 'haircut' },
  { name: 'Cockapoo', tier: 'excluded', reason: 'haircut' },
  { name: 'Cocker Spaniel', tier: 'excluded', reason: 'haircut' },
  { name: 'Coton de Tulear', tier: 'excluded', reason: 'haircut' },
  { name: 'Havanese', tier: 'excluded', reason: 'haircut' },
  { name: 'Labradoodle', tier: 'excluded', reason: 'haircut' },
  { name: 'Lhasa Apso', tier: 'excluded', reason: 'haircut' },
  { name: 'Maltipoo', tier: 'excluded', reason: 'haircut' },
  { name: 'Old English Sheepdog', tier: 'excluded', reason: 'haircut' },
  { name: 'Pekingese', tier: 'excluded', reason: 'haircut' },
  { name: 'Pomeranian', tier: 'excluded', reason: 'haircut' },
  { name: 'Poodle (Standard, Miniature, or Toy)', tier: 'excluded', reason: 'haircut' },
  { name: 'Portuguese Water Dog', tier: 'excluded', reason: 'haircut' },
  { name: 'Schnauzer (any size)', tier: 'excluded', reason: 'haircut' },
  { name: 'Scottish Terrier', tier: 'excluded', reason: 'haircut' },
  { name: 'Westie (West Highland Terrier)', tier: 'excluded', reason: 'haircut' },
  { name: 'Wheaten Terrier', tier: 'excluded', reason: 'haircut' },

  // Excluded: excessive double coats (hours, not a route stop)
  { name: 'Akita', tier: 'excluded', reason: 'coat' },
  { name: 'Alaskan Malamute', tier: 'excluded', reason: 'coat' },
  { name: 'Chow Chow', tier: 'excluded', reason: 'coat' },
  { name: 'Great Pyrenees', tier: 'excluded', reason: 'coat' },
  { name: 'Keeshond', tier: 'excluded', reason: 'coat' },
  { name: 'Samoyed', tier: 'excluded', reason: 'coat' },
  { name: 'Siberian Husky', tier: 'excluded', reason: 'coat' },

  // Excluded: excessively large dogs (get in and out is the business)
  { name: 'Anatolian Shepherd', tier: 'excluded', reason: 'size' },
  { name: 'Bernese Mountain Dog', tier: 'excluded', reason: 'size' },
  { name: 'Great Dane', tier: 'excluded', reason: 'size' },
  { name: 'Irish Wolfhound', tier: 'excluded', reason: 'size' },
  { name: 'Leonberger', tier: 'excluded', reason: 'size' },
  { name: 'Mastiff (any mastiff breed)', tier: 'excluded', reason: 'size' },
  { name: 'Newfoundland', tier: 'excluded', reason: 'size' },
  { name: 'Saint Bernard', tier: 'excluded', reason: 'size' },
];

export const COMMON_BREEDS = BREEDS.filter((b) => b.common).sort((a, b) => a.common - b.common);
export const OTHER_BREEDS = BREEDS.filter((b) => !b.common).sort((a, b) => a.name.localeCompare(b.name));

export const TIER_LABEL = { smoothcoat: 'Smoothcoat', doublecoat: 'Doublecoat' };

// The kind declines, one per reason the dog is not a fit.
export const DECLINE_COPY = {
  haircut: 'We have to be honest up front: that coat needs haircut-level dog grooming, and dogs that do not need haircuts are the whole point of this service. A full-service dog grooming salon is the right home for that coat, and we would rather tell you here, kindly, than at your door.',
  coat: 'We have to be honest up front: coats like this one (Huskies, Malamutes, Samoyeds, Chows) carry more undercoat than a mobile route stop can do justice. A full-service dog grooming salon is the right home for that coat, and we would rather tell you here, kindly, than at your door.',
  size: 'We have to be honest up front: the gentle giants (Great Danes, Saint Bernards, Newfoundlands and friends) need more room and more time than our get-in-get-out route stops can give. A full-service dog grooming salon is the right home, and we would rather tell you here, kindly, than at your door.',
};

export function breedByName(name) {
  return BREEDS.find((b) => b.name === name) || null;
}

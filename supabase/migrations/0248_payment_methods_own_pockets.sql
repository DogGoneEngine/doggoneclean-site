-- Payment methods that settle to their own account get their own labels.
--
-- "wallet" used to be the catch-all for every phone-tap payment, which lumped
-- PayPal (and Cash App and Venmo) in with Apple/Google/Samsung Pay. But the
-- Apple/Google/Samsung wallets all settle through Square alongside cards, while
-- PayPal, Cash App, and Venmo each land in their own separate account. Filing
-- those as "wallet" made them look like they belonged in the Square deposits,
-- so reconciliation chased money that was never going to be there.
--
-- After this, "wallet" means a phone tap that settles through Square (Apple,
-- Google, Samsung Pay); paypal, cashapp, and venmo are their own pockets.

alter table public.visits
  drop constraint if exists visits_payment_method_check;

alter table public.visits
  add constraint visits_payment_method_check
  check (
    payment_method is null
    or payment_method = any (array[
      'square_in_person'::text,
      'stripe_card'::text,
      'cash'::text,
      'wallet'::text,
      'paypal'::text,
      'cashapp'::text,
      'venmo'::text
    ])
  );

-- Steve Crandall has only ever paid by PayPal (confirmed by Paul, 2026-06-25);
-- relabel his back-history that was filed as the generic "wallet".
update public.visits
  set payment_method = 'paypal'
  where client_id = 'f726afb5-0285-46c9-82cd-afa630f8beb4'
    and payment_method = 'wallet';

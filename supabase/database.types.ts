export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      bath_appointments: {
        Row: {
          amount_cents: number
          charged_at: string | null
          created_at: string
          dog_count: number
          id: string
          notes: string | null
          original_scheduled_start: string | null
          payment_status: string
          scheduled_end: string | null
          scheduled_start: string
          status: string
          stripe_payment_intent_id: string | null
          subscriber_id: string
          subscription_id: string | null
          updated_at: string
        }
        Insert: {
          amount_cents: number
          charged_at?: string | null
          created_at?: string
          dog_count?: number
          id?: string
          notes?: string | null
          original_scheduled_start?: string | null
          payment_status?: string
          scheduled_end?: string | null
          scheduled_start: string
          status?: string
          stripe_payment_intent_id?: string | null
          subscriber_id: string
          subscription_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          charged_at?: string | null
          created_at?: string
          dog_count?: number
          id?: string
          notes?: string | null
          original_scheduled_start?: string | null
          payment_status?: string
          scheduled_end?: string | null
          scheduled_start?: string
          status?: string
          stripe_payment_intent_id?: string | null
          subscriber_id?: string
          subscription_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bath_appointments_subscriber_id_fkey"
            columns: ["subscriber_id"]
            isOneToOne: false
            referencedRelation: "bath_subscribers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bath_appointments_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "bath_subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
      bath_dogs: {
        Row: {
          active: boolean
          behavior_notes: string | null
          birth_date: string | null
          breed: string | null
          coat_tier: string | null
          created_at: string
          dob_approximate: boolean
          id: string
          name: string
          subscriber_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          behavior_notes?: string | null
          birth_date?: string | null
          breed?: string | null
          coat_tier?: string | null
          created_at?: string
          dob_approximate?: boolean
          id?: string
          name: string
          subscriber_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          behavior_notes?: string | null
          birth_date?: string | null
          breed?: string | null
          coat_tier?: string | null
          created_at?: string
          dob_approximate?: boolean
          id?: string
          name?: string
          subscriber_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bath_dogs_subscriber_id_fkey"
            columns: ["subscriber_id"]
            isOneToOne: false
            referencedRelation: "bath_subscribers"
            referencedColumns: ["id"]
          },
        ]
      }
      bath_subscribers: {
        Row: {
          address_city: string | null
          address_line_1: string | null
          address_state: string | null
          address_zip: string | null
          auth_user_id: string | null
          city_id: string | null
          created_at: string
          email: string | null
          email_opt_in: boolean
          first_name: string | null
          id: string
          is_test: boolean
          last_name: string | null
          last_profile_confirmed_at: string | null
          phone_e164: string | null
          service_lat: number | null
          service_lng: number | null
          sms_opt_in: boolean
          stripe_customer_id: string | null
          updated_at: string
        }
        Insert: {
          address_city?: string | null
          address_line_1?: string | null
          address_state?: string | null
          address_zip?: string | null
          auth_user_id?: string | null
          city_id?: string | null
          created_at?: string
          email?: string | null
          email_opt_in?: boolean
          first_name?: string | null
          id?: string
          is_test?: boolean
          last_name?: string | null
          last_profile_confirmed_at?: string | null
          phone_e164?: string | null
          service_lat?: number | null
          service_lng?: number | null
          sms_opt_in?: boolean
          stripe_customer_id?: string | null
          updated_at?: string
        }
        Update: {
          address_city?: string | null
          address_line_1?: string | null
          address_state?: string | null
          address_zip?: string | null
          auth_user_id?: string | null
          city_id?: string | null
          created_at?: string
          email?: string | null
          email_opt_in?: boolean
          first_name?: string | null
          id?: string
          is_test?: boolean
          last_name?: string | null
          last_profile_confirmed_at?: string | null
          phone_e164?: string | null
          service_lat?: number | null
          service_lng?: number | null
          sms_opt_in?: boolean
          stripe_customer_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bath_subscribers_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
        ]
      }
      bath_subscriptions: {
        Row: {
          additional_dog_decrement_cents: number
          base_price_cents: number
          cadence: string
          cancelled_at: string | null
          city_id: string
          consecutive_no_shows: number
          created_at: string
          founders_locked_until: string | null
          id: string
          is_founders: boolean
          last_skip_at: string | null
          last_skip_priced_at: string | null
          paused_at: string | null
          paused_reason: string | null
          started_at: string
          status: string
          stripe_payment_method_id: string | null
          subscriber_id: string
          updated_at: string
        }
        Insert: {
          additional_dog_decrement_cents?: number
          base_price_cents: number
          cadence: string
          cancelled_at?: string | null
          city_id: string
          consecutive_no_shows?: number
          created_at?: string
          founders_locked_until?: string | null
          id?: string
          is_founders?: boolean
          last_skip_at?: string | null
          last_skip_priced_at?: string | null
          paused_at?: string | null
          paused_reason?: string | null
          started_at?: string
          status?: string
          stripe_payment_method_id?: string | null
          subscriber_id: string
          updated_at?: string
        }
        Update: {
          additional_dog_decrement_cents?: number
          base_price_cents?: number
          cadence?: string
          cancelled_at?: string | null
          city_id?: string
          consecutive_no_shows?: number
          created_at?: string
          founders_locked_until?: string | null
          id?: string
          is_founders?: boolean
          last_skip_at?: string | null
          last_skip_priced_at?: string | null
          paused_at?: string | null
          paused_reason?: string | null
          started_at?: string
          status?: string
          stripe_payment_method_id?: string | null
          subscriber_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bath_subscriptions_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bath_subscriptions_subscriber_id_fkey"
            columns: ["subscriber_id"]
            isOneToOne: false
            referencedRelation: "bath_subscribers"
            referencedColumns: ["id"]
          },
        ]
      }
      cities: {
        Row: {
          center_lat: number | null
          center_lng: number | null
          created_at: string
          hb_active: boolean
          hb_addon_decrement_cents: number
          hb_doublecoat_recurring_cents: number | null
          hb_doublecoat_single_cents: number | null
          hb_founders_cap: number
          hb_founders_doublecoat_cents: number | null
          hb_founders_smoothcoat_cents: number | null
          hb_smoothcoat_recurring_cents: number | null
          hb_smoothcoat_single_cents: number | null
          id: string
          name: string
          polygon: Json
          slug: string
          state: string
          updated_at: string
        }
        Insert: {
          center_lat?: number | null
          center_lng?: number | null
          created_at?: string
          hb_active?: boolean
          hb_addon_decrement_cents?: number
          hb_doublecoat_recurring_cents?: number | null
          hb_doublecoat_single_cents?: number | null
          hb_founders_cap?: number
          hb_founders_doublecoat_cents?: number | null
          hb_founders_smoothcoat_cents?: number | null
          hb_smoothcoat_recurring_cents?: number | null
          hb_smoothcoat_single_cents?: number | null
          id?: string
          name: string
          polygon?: Json
          slug: string
          state: string
          updated_at?: string
        }
        Update: {
          center_lat?: number | null
          center_lng?: number | null
          created_at?: string
          hb_active?: boolean
          hb_addon_decrement_cents?: number
          hb_doublecoat_recurring_cents?: number | null
          hb_doublecoat_single_cents?: number | null
          hb_founders_cap?: number
          hb_founders_doublecoat_cents?: number | null
          hb_founders_smoothcoat_cents?: number | null
          hb_smoothcoat_recurring_cents?: number | null
          hb_smoothcoat_single_cents?: number | null
          id?: string
          name?: string
          polygon?: Json
          slug?: string
          state?: string
          updated_at?: string
        }
        Relationships: []
      }
      clients: {
        Row: {
          access: Json
          aka: string | null
          availability_hard: string | null
          availability_not_days: string[]
          availability_seasonal: string | null
          availability_soft: string | null
          cadence_confidence: string | null
          cadence_days: number | null
          cadence_note: string | null
          created_at: string
          data_gaps: string[]
          exclude_from_everything: boolean
          flags: string[]
          hardness: string | null
          id: string
          location_address: string | null
          location_geo_notes: string | null
          location_plus: string | null
          location_zip: string | null
          location_zone: string | null
          name: string
          note: string | null
          relationships: string[]
          roster_group: string
          routed: boolean
          service_type: string | null
          status: string
          updated_at: string
        }
        Insert: {
          access?: Json
          aka?: string | null
          availability_hard?: string | null
          availability_not_days?: string[]
          availability_seasonal?: string | null
          availability_soft?: string | null
          cadence_confidence?: string | null
          cadence_days?: number | null
          cadence_note?: string | null
          created_at?: string
          data_gaps?: string[]
          exclude_from_everything?: boolean
          flags?: string[]
          hardness?: string | null
          id?: string
          location_address?: string | null
          location_geo_notes?: string | null
          location_plus?: string | null
          location_zip?: string | null
          location_zone?: string | null
          name: string
          note?: string | null
          relationships?: string[]
          roster_group: string
          routed?: boolean
          service_type?: string | null
          status: string
          updated_at?: string
        }
        Update: {
          access?: Json
          aka?: string | null
          availability_hard?: string | null
          availability_not_days?: string[]
          availability_seasonal?: string | null
          availability_soft?: string | null
          cadence_confidence?: string | null
          cadence_days?: number | null
          cadence_note?: string | null
          created_at?: string
          data_gaps?: string[]
          exclude_from_everything?: boolean
          flags?: string[]
          hardness?: string | null
          id?: string
          location_address?: string | null
          location_geo_notes?: string | null
          location_plus?: string | null
          location_zip?: string | null
          location_zone?: string | null
          name?: string
          note?: string | null
          relationships?: string[]
          roster_group?: string
          routed?: boolean
          service_type?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      dogs: {
        Row: {
          breed: string | null
          client_id: string
          created_at: string
          id: string
          name: string
          notes: string | null
          price_cents: number | null
          updated_at: string
        }
        Insert: {
          breed?: string | null
          client_id: string
          created_at?: string
          id?: string
          name: string
          notes?: string | null
          price_cents?: number | null
          updated_at?: string
        }
        Update: {
          breed?: string | null
          client_id?: string
          created_at?: string
          id?: string
          name?: string
          notes?: string | null
          price_cents?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dogs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: { [_ in never]: never }
    Functions: { [_ in never]: never }
    Enums: { [_ in never]: never }
    CompositeTypes: { [_ in never]: never }
  }
}

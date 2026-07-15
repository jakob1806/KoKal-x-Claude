"use client";

import { useState } from "react";
import { Field, TextArea, TextInput } from "@/components/form-fields";
import { SubmitButton } from "@/components/submit-button";

function slugify(value: string) {
  return value
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export interface VenueFormValues {
  slug: string;
  name: string;
  description_de: string | null;
  address_street: string;
  address_zip: string;
  address_city: string;
  lat: number | null;
  lng: number | null;
  capacity: number | null;
  website_url: string | null;
}

export function VenueForm({
  action,
  initial,
}: {
  action: (formData: FormData) => void;
  initial?: VenueFormValues;
}) {
  const [slug, setSlug] = useState(initial?.slug ?? "");
  const [slugTouched, setSlugTouched] = useState(Boolean(initial));

  return (
    <form action={action} className="flex max-w-xl flex-col gap-4">
      <Field label="Name" required>
        <TextInput
          name="name"
          required
          defaultValue={initial?.name}
          onChange={(e) => {
            if (!slugTouched) setSlug(slugify(e.target.value));
          }}
        />
      </Field>

      <Field label="Slug (URL)" required>
        <TextInput
          name="slug"
          required
          value={slug}
          onChange={(e) => {
            setSlugTouched(true);
            setSlug(e.target.value);
          }}
        />
      </Field>

      <Field label="Beschreibung">
        <TextArea name="description_de" rows={3} defaultValue={initial?.description_de ?? ""} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Straße & Hausnummer" required>
          <TextInput name="address_street" required defaultValue={initial?.address_street} />
        </Field>
        <Field label="PLZ" required>
          <TextInput name="address_zip" required defaultValue={initial?.address_zip} />
        </Field>
      </div>

      <Field label="Stadt" required>
        <TextInput name="address_city" required defaultValue={initial?.address_city ?? "München"} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Breitengrad (lat)" required>
          <TextInput
            name="lat"
            type="number"
            step="any"
            required
            defaultValue={initial?.lat ?? ""}
            placeholder="48.1351"
          />
        </Field>
        <Field label="Längengrad (lng)" required>
          <TextInput
            name="lng"
            type="number"
            step="any"
            required
            defaultValue={initial?.lng ?? ""}
            placeholder="11.5820"
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Kapazität">
          <TextInput name="capacity" type="number" defaultValue={initial?.capacity ?? ""} />
        </Field>
        <Field label="Website">
          <TextInput name="website_url" type="url" defaultValue={initial?.website_url ?? ""} />
        </Field>
      </div>

      <div className="mt-2">
        <SubmitButton>{initial ? "Speichern" : "Venue anlegen"}</SubmitButton>
      </div>
    </form>
  );
}

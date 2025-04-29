# Supabase Next.js SaaS Template

A production-ready SaaS template built with Next.js 15, Supabase, and Tailwind CSS. This template provides everything you need to quickly launch your SaaS product, including authentication, user management, file storage, and more.

## LIVE DEMO

Demo is here - https://basicsass.razikus.com


## Deployment video

Video is here - https://www.youtube.com/watch?v=kzbXavLndmE


## SupaNuggets

On top of this template I'm building a SupaNuggets series - 50 mini apps

https://supanuggets.razikus.com - grab your copy for free :) (Pay As You Want model)

## 🚀 Features

- **Authentication**
    - Email/Password authentication
    - Multi-factor authentication (MFA) support
    - OAuth/SSO integration ready
    - Password reset and email verification

- **User Management**
    - User profiles and settings
    - Secure password management
    - Session handling

- **File Management Demo (2FA ready)**
    - Secure file upload and storage
    - File sharing capabilities
    - Drag-and-drop interface
    - Progress tracking

- **Task Management Demo (2FA ready)**
    - CRUD operations example
    - Real-time updates
    - Filtering and sorting
    - Row-level security

- **Security**
    - Row Level Security (RLS) policies
    - Secure file storage policies
    - Protected API routes
    - MFA implementation

- **UI/UX**
    - Modern, responsive design
    - Dark mode support
    - Loading states
    - Error handling
    - Toast notifications
    - Confetti animations

- **Legal & Compliance**
    - Privacy Policy template
    - Terms of Service template
    - Refund Policy template
    - GDPR-ready cookie consent

## 🛠️ Tech Stack

- **Frontend**
    - Next.js 15 (App Router)
    - React 19
    - Tailwind CSS
    - shadcn/ui components
    - Lucide icons

- **Backend**
    - Supabase
    - PostgreSQL
    - Row Level Security
    - Storage Buckets

- **Authentication**
    - Supabase Auth
    - MFA support
    - OAuth providers

## 📦 Getting Started - local dev

1. Fork or clone repository
2. Prepare Supabase Project URL (Project URL from `Project Settings` -> `API` -> `Project URL`)
3. Prepare Supabase Anon and Service Key (`Anon Key`, `Service Key` from `Project Settings` -> `API` -> `anon public` and `service_role`)
4. Prepare Supabase Database Password  (You can reset it inside `Project Settings` -> `Database` -> `Database Password`)
5. If you already know your app url -> adjust supabase/config.toml `site_url` and `additional_redirect_urls`, you can do it later
6. Run following commands (inside root of forked / downloaded repository):

```bash
# Login to supabase
npx supabase login
# Link project to supabase (require database password) - you will get selector prompt
npx supabase link

# Send config to the server - may require confirmation (y)
npx supabase config push

# Up migrations
npx supabase migrations up --linked

```

7. Go to next/js folder and run `yarn`
8. Copy .env.template to .env.local
9. Adjust .env.local
```
NEXT_PUBLIC_SUPABASE_URL=https://APIURL
NEXT_PUBLIC_SUPABASE_ANON_KEY=ANONKEY
PRIVATE_SUPABASE_SERVICE_KEY=SERVICEROLEKEY

```
10. Run yarn dev
11. Go to http://localhost:3000 🎉

## 🚀 Getting Started - deploy to vercel

1. Fork or clone repository
2. Create project in Vercel - choose your repo
3. Paste content of .env.local into environment variables
4. Click deploy
5. Adjust in supabase/config.toml site_url and additional_redirect_urls (important in additional_redirect_urls is to have https://YOURURL/** - these 2 **)
6. Done!

## 📄 Legal Documents

The template includes customizable legal documents - these are in markdown, so you can adjust them as you see fit:

- Privacy Policy (`/public/terms/privacy-notice.md`)
- Terms of Service (`/public/terms/terms-of-service.md`)
- Refund Policy (`/public/terms/refund-policy.md`)

## 🎨 Theming

The template includes several pre-built themes:
- `theme-sass` (Default)
- `theme-blue`
- `theme-purple`
- `theme-green`

Change the theme by updating the `NEXT_PUBLIC_THEME` environment variable.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## Need Multitenancy, Billing (Paddle) and Role Based Access Control?

I have paid template as well available here:

https://sasstemplate.razikus.com

Basically it's the same template but with Paddle + organisations API keys + multiple organisations + Role Based Access Control

For code GITHUB you can get -50% off

https://razikus.gumroad.com/l/supatemplate/GITHUB

## 📝 License

This project is licensed under the Apache License - see the LICENSE file for details.

## 💪 Support

If you find this template helpful, please consider giving it a star ⭐️

Or buy me a coffee!

- [BuyMeACoffee](https://buymeacoffee.com/razikus)

My socials:

- [Twitter](https://twitter.com/Razikus_)
- [GitHub](https://github.com/Razikus)
- [Website](https://www.razikus.com)


## 🙏 Acknowledgments

- [Next.js](https://nextjs.org/)
- [Supabase](https://supabase.com/)
- [Tailwind CSS](https://tailwindcss.com/)
- [shadcn/ui](https://ui.shadcn.com/)

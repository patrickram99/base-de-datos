import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

// Define public routes (these will not require authentication)
const publicRoutes = createRouteMatcher([
  '/',
  '/sign-in(.*)',
  '/sign-up(.*)'
])

// Define protected routes (these will require authentication)
const protectedRoutes = createRouteMatcher([
  '/dashboard(.*)',
  '/debate(.*)',
  '/api(.*)',
  '/trpc(.*)'
])

export default clerkMiddleware(async (auth, request) => {
  // If it's a protected route, require authentication
  if (protectedRoutes(request)) {
    await auth.protect()
    return
  }

  // If it's not a public route and not explicitly protected,
  // we'll protect it by default for security
  if (!publicRoutes(request)) {
    await auth.protect()
  }
})

export const config = {
  matcher: [
    // Skip Next.js internals and all static files
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always include API routes
    '/(api|trpc)(.*)',
  ],
}
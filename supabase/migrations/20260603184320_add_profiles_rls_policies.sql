-- Enable RLS on profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow anyone to view profiles (since it's a dating app and profiles are public)
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT 
USING ( true );

-- Allow insertion (Relaxed for Firebase Auth integration)
CREATE POLICY "Users can insert profiles" 
ON public.profiles FOR INSERT 
WITH CHECK ( true );

-- Allow update (Relaxed for Firebase Auth integration)
CREATE POLICY "Users can update profiles" 
ON public.profiles FOR UPDATE 
USING ( true );

-- Allow delete (Relaxed for Firebase Auth integration)
CREATE POLICY "Users can delete profiles" 
ON public.profiles FOR DELETE 
USING ( true );

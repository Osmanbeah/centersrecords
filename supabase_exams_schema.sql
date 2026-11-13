-- =========================================================================
-- CENTERS RECORD: EXAMS & BUBBLE SHEET OMR SCANNER SCHEMA
-- =========================================================================

-- 1. Exams Table (Created and configured exclusively by Admin)
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    title TEXT NOT NULL,
    subject TEXT DEFAULT 'Chemistry',
    exam_date DATE DEFAULT CURRENT_DATE,
    center TEXT DEFAULT 'All Centers',
    question_count INT DEFAULT 30,
    mcq_score_per_q NUMERIC DEFAULT 1,
    written_max_score NUMERIC DEFAULT 20,
    total_score NUMERIC DEFAULT 50,
    models JSONB DEFAULT '{"A": {}}'::jsonb,
    status TEXT DEFAULT 'active' -- 'active' | 'closed'
);

-- 2. Exam Results Table (Scanned by Assistants, reviewed by Admin)
CREATE TABLE IF NOT EXISTS public.exam_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
    student_name TEXT,
    student_code TEXT,
    center TEXT,
    model TEXT DEFAULT 'A',
    mcq_score NUMERIC DEFAULT 0,
    written_score NUMERIC DEFAULT 0,
    total_score NUMERIC DEFAULT 0,
    student_answers JSONB DEFAULT '{}'::jsonb,
    assistant_name TEXT,
    notes TEXT
);

-- 3. Row Level Security & Access Policies
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read/write on exams" ON public.exams;
CREATE POLICY "Allow public read/write on exams" ON public.exams FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.exam_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read/write on exam_results" ON public.exam_results;
CREATE POLICY "Allow public read/write on exam_results" ON public.exam_results FOR ALL USING (true) WITH CHECK (true);

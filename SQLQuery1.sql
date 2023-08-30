SELECT *
FROM covid..covidDeaths$
ORDER BY 3,4;


--SELECT *
--FROM covid..covidVaccination$
--ORDER BY 3,4

-- Select data that will be used
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM covid..covidDeaths$
ORDER BY 1,2;


-- Change datatype, as those columns are nvarchar
ALTER TABLE covid..covidDeaths$ ALTER COLUMN total_deaths FLOAT
ALTER TABLE covid..covidDeaths$ ALTER COLUMN total_cases FLOAT;


-- Total cases vs Total deaths
-- Likelihood of dying in Mexico if you get infected by COVID-19
SELECT location, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
FROM covid..covidDeaths$
WHERE location LIKE '%mexico%'
ORDER BY 1,2;


-- Total cases vs Population
-- % of population in Mexico infected by COVID-19
SELECT location, date, population, total_cases, (total_cases/population)*100 as PopulationPercentage
FROM covid..covidDeaths$
WHERE location LIKE '%mexico%'
ORDER BY 1,2;

--TABLE 1
-- Countries with Higher Infection Rate vs Population
SELECT location, population, MAX(total_cases) AS HIR, MAX((total_cases/population))*100 as PopulationPercentage
FROM covid..covidDeaths$
--WHERE location LIKE '%mexico%'
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PopulationPercentage DESC;


-- Countries with Higher Death Rate vs Population
SELECT location, MAX(total_deaths) AS HIR
FROM covid..covidDeaths$
--WHERE location LIKE '%mexico%'
GROUP BY location
ORDER BY HIR DESC;


-- Location is showing groups of continets.
SELECT *
FROM covid..covidDeaths$
ORDER BY 3,4;


-- TABLE 2
-- Reason is: There exists some rows without a continent, excluding them
-- will take them from the countries list
-- Countries with Higher Death Rate vs Population
SELECT location, MAX(total_deaths) AS HIR
FROM covid..covidDeaths$
--WHERE location LIKE '%mexico%'
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY HIR DESC;


--TABLE 3
-- Continents with Higher Death Rate vs Population
SELECT continent, MAX(total_deaths) AS HIR
FROM covid..covidDeaths$
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY HIR DESC;


--TABLE 4
-- Countries with Higher Case Rate vs Death Rate
WITH cases_vs_deaths (Location, Population, Total_Cases, Total_Deaths)
AS 
(
	SELECT location, population, MAX(total_cases) as Total_Cases, MAX(total_deaths) AS TotalDeaths
	FROM covid..covidDeaths$
	WHERE continent IS NOT NULL
	GROUP BY location, population
)
SELECT * , (Total_Deaths/Total_Cases)*100 as Case_VS_DeathRate
FROM cases_vs_deaths
ORDER BY Case_VS_DeathRate DESC

-- TABLEAU VISUALIZATION
-- TABLE 5
-- Global Death Percentage per date (01/01/2020 - 18/08/2023)
SELECT date, SUM(new_cases) as TotalCases, SUM(new_deaths) as TotalDeaths, SUM(new_deaths)/NULLIF(SUM(new_cases),0)*100 as DeathPercentage
FROM covid..covidDeaths$
WHERE continent IS NOT NULL 
GROUP BY date
ORDER BY 1,2;


-- TABLEAU VISUALIZATION
-- TABLE 6
-- Global Death Percentage
SELECT SUM(new_cases) as TotalCases, SUM(new_deaths) as TotalDeaths, SUM(new_deaths)/NULLIF(SUM(new_cases),0)*100 as DeathPercentage
FROM covid..covidDeaths$
WHERE continent IS NOT NULL 
ORDER BY 1,2;


-- Join Death and Vaccination on Location and Date
SELECT * 
FROM covid..covidDeaths$ death
JOIN covid..covidVaccination$ vaccine
	ON death.location = vaccine.location
	AND death.date = vaccine.date;


-- TABLE 7
-- Total population vs Vaccinations per Country-Date using CTE 
WITH pop_vs_vacc (Continent, Location, Date, Population, New_Vaccinations, Accumulated_Vaccinations)
AS(
	SELECT death.continent, death.location, death.date, death.population, vaccine.new_vaccinations, SUM(ISNULL(CONVERT(BIGINT, vaccine.new_vaccinations),0)) 
		OVER (PARTITION BY death.location ORDER BY death.location, death.date) AS SumOfVaccination
	FROM covid..covidDeaths$ death
	JOIN covid..covidVaccination$ vaccine
		ON death.location = vaccine.location
		AND death.date = vaccine.date
	WHERE death.continent IS NOT NULL
)
SELECT *, (Accumulated_Vaccinations/Population)*100 AS AccumulatedPercentage
FROM pop_vs_vacc;


-- TABLE 8
-- Total population vs Vaccinations Per Country using CTE 
WITH pop_vs_vacc (Continent, Location, Date, Population, New_Vaccinations, Accumulated_Vaccinations, Full_Vaccination)
AS(
   SELECT death.continent, death.location, death.date, death.population, vaccine.new_vaccinations, SUM(ISNULL(CONVERT(BIGINT, vaccine.new_vaccinations),0)) 
		OVER (PARTITION BY death.location ORDER BY death.location, death.date) AS SumOfVaccination,  CONVERT(BIGINT, people_fully_vaccinated) AS Full_Vacc
	FROM covid..covidDeaths$ death
	JOIN covid..covidVaccination$ vaccine
		ON death.location = vaccine.location
		AND death.date = vaccine.date
	WHERE death.continent IS NOT NULL
	)
SELECT Location, Population, MAX(Accumulated_Vaccinations) AS AccumulatedVaccinations, MAX(Full_Vaccination) AS Vaccination
FROM pop_vs_vacc
GROUP BY Location, Population
ORDER BY AccumulatedVaccinations DESC;


-- TABLE 9
-- Total Population vs People Fully Vaccinated Per Country 
SELECT vaccine.location, death.population, MAX(CONVERT(BIGINT, people_fully_vaccinated)) AS Full_Vacc
FROM covid..covidVaccination$ vaccine
JOIN covid..covidDeaths$ death
	ON vaccine.location = death.location
WHERE vaccine.continent IS NOT NULL
GROUP BY vaccine.location, death.population
ORDER BY Full_Vacc DESC;


-- TABLE 9
-- Total Population vs People Fully Vaccinated Per Country 
SELECT vaccine.location, MAX(death.total_cases) AS InfectedPeople, MAX(CONVERT(BIGINT, people_fully_vaccinated)) AS Full_Vacc
FROM covid..covidVaccination$ vaccine
JOIN covid..covidDeaths$ death
	ON vaccine.location = death.location
WHERE vaccine.continent IS NOT NULL
GROUP BY vaccine.location
ORDER BY Full_Vacc DESC;


-- TABLE 10
--Smoker Population vs Infected Population per Country
SELECT q1.Location, q1.Population, q2.Total_Cases, q1.Female_Smokers, q1.Male_Smokers, q1.Total_Smokers, q2.InfectedPopulationPercentage
FROM 
(
	SELECT
		death.location AS Location,
		death.population AS Population,
		MAX(CONVERT(FLOAT,vaccine.female_smokers)) AS Female_Smokers,
		MAX(CONVERT(FLOAT,vaccine.male_smokers)) AS Male_Smokers,
		MAX(CONVERT(FLOAT,vaccine.female_smokers)) + MAX(CONVERT(FLOAT,vaccine.male_smokers)) AS Total_Smokers
	FROM covid..covidDeaths$ death
	JOIN covid..covidVaccination$ vaccine 
		ON death.location = vaccine.location
	WHERE death.continent IS NOT NULL
	GROUP BY death.location, death.population
) AS q1
JOIN 
(
    SELECT location, MAX(total_cases) AS Total_Cases, MAX((total_cases/population))*100 as InfectedPopulationPercentage
    FROM covid..covidDeaths$
    WHERE continent IS NOT NULL
    GROUP BY location, population
) AS q2 
	ON q1.Location = q2.location
ORDER BY q2.InfectedPopulationPercentage DESC;


--TABLE 11
--Smoker Population vs Death Population per Country
SELECT q1.Location, q1.Population, q2.Total_Deaths, q1.Female_Smokers, q1.Male_Smokers, q1.Total_Smokers, q2.DeathPopulationPercentage
FROM 
(
	SELECT
		death.location AS Location,
		death.population AS Population,
		MAX(CONVERT(FLOAT,vaccine.female_smokers)) AS Female_Smokers,
		MAX(CONVERT(FLOAT,vaccine.male_smokers)) AS Male_Smokers,
		MAX(CONVERT(FLOAT,vaccine.female_smokers)) + MAX(CONVERT(FLOAT,vaccine.male_smokers)) AS Total_Smokers
	FROM covid..covidDeaths$ death
	JOIN covid..covidVaccination$ vaccine 
		ON death.location = vaccine.location
	WHERE death.continent IS NOT NULL
	GROUP BY death.location, death.population
) AS q1
JOIN 
(
    SELECT location, MAX(total_deaths) AS Total_Deaths, MAX((total_deaths/population))*100 as DeathPopulationPercentage
    FROM covid..covidDeaths$
    WHERE continent IS NOT NULL
    GROUP BY location, population
) AS q2 
	ON q1.Location = q2.location
ORDER BY q2.DeathPopulationPercentage DESC;


-- TABLEAU VISUALIZATION
-- TABLE 12
-- Population per country
WITH pop_vs_vacc (Continent, Location, Date, Population, New_Vaccinations, Accumulated_Vaccinations, Full_Vaccination)
AS(
   SELECT death.continent, death.location, death.date, death.population, vaccine.new_vaccinations, SUM(ISNULL(CONVERT(BIGINT, vaccine.new_vaccinations),0)) 
		OVER (PARTITION BY death.location ORDER BY death.location, death.date) AS SumOfVaccination,  CONVERT(BIGINT, people_fully_vaccinated) AS Full_Vacc
	FROM covid..covidDeaths$ death
	JOIN covid..covidVaccination$ vaccine
		ON death.location = vaccine.location
		AND death.date = vaccine.date
	WHERE death.continent IS NOT NULL
	)
SELECT q2.continent, q2.location, q2.population,  q2.Infected_Population, q2.Death_Population, q1.AccumulatedVaccinations, q1.Vaccination
FROM
(
-- TABLE 9
-- Total Population vs People Fully Vaccinated Per Country 
SELECT Location, Population, MAX(Accumulated_Vaccinations) AS AccumulatedVaccinations, MAX(Full_Vaccination) AS Vaccination
FROM pop_vs_vacc
GROUP BY Location, Population
) AS q1
JOIN
(
--TABLE 1
-- Countries with Higher Infection Rate vs Population
SELECT location, population, continent, MAX(total_cases) AS Infected_Population,  MAX(total_deaths) AS Death_Population
FROM covid..covidDeaths$
WHERE continent IS NOT NULL
GROUP BY location, population, continent
) AS q2
ON q1.location = q2.location
ORDER BY q1.Vaccination DESC;





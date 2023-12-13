-- Segment 1: Database - Tables, Columns, Relationships

-- What are the different tables in the database and how are they connected to each other in the database?
-- ERD


-- Find the total number of rows in each table of the schema.
SELECT TABLE_NAME,TABLE_ROWS FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='imdb';


-- Identify which columns in the movie table have null values.
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_NAME='movies' 
 AND IS_NULLABLE='YES'
 AND TABLE_SCHEMA='imdb';


-- Segment 2: Movie Release Trends

-- Determine the total number of movies released each year and analyse the month-wise trend.
SELECT year,date_format(date_published,"%M") as month,count(id) as no_of_movies FROM movies
group by year, date_format(date_published,"%M")
order by year, month ;


-- Calculate the number of movies produced in the USA or India in the year 2019.
select count(*) from movies
where year=2019 and
(country like '%USA%' 
OR country like '%India%')
group by year;


-- Segment 3: Production Statistics and Genre Analysis

-- Retrieve the unique list of genres present in the dataset.
select distinct genre from genre;


-- Identify the genre with the highest number of movies produced overall.
select genre,count(movie_id) as no_of_movies,
dense_rank() over(order by count(*) desc) as 'rk'
from genre
group by genre
limit 1;

-- Determine the count of movies that belong to only one genre.
select count(movie_id) from
(select movie_id, count(distinct genre) from genre
group by movie_id
having count(distinct genre)=1) t;

-- Calculate the average duration of movies in each genre.
select g.genre,round(avg(m.duration),2) as avg_duration
from movies m join
genre g on
m.id=g.movie_id
group by g.genre
order by avg_duration desc;

/*using cte*/
with genre_cte as
(select a.*,b.genre from movies a join
genre b on a.id=b.movie_id)
select genre,avg(duration)
from genre_cte group by genre
order by avg(duration) desc;

-- Find the rank of the 'thriller' genre among all genres in terms of the number of movies produced.

with movie_produced_cte as
(select g.genre,count(m.id) as no_of_movies,rank() over(order by count(m.id) desc) as genre_rank
from genre g join movies m
on g.movie_id=m.id
group by g.genre
order by no_of_movies desc)

select * from movie_produced_cte where genre='Thriller'
;

-- Segment 4: Ratings Analysis and Crew Members

-- Retrieve the minimum and maximum values in each column of the ratings table (except movie_id).
select min(avg_rating) as min_avg_rating,max(avg_rating) as max_avg_rating,
min(total_votes) as min_total_votes,max(total_votes) as max_total_votes,
min(median_rating) as min_median_rating,max(median_rating) as max_median_rating
from ratings;

-- Identify the top 10 movies based on average rating.
 select title, avg_rating, movie_rk from
(select m.title,r.avg_rating,row_number() over(order by r.avg_rating desc) as movie_rk from movies m
left join ratings r on r.movie_id=m.id) t
where movie_rk<=10;


-- Summarise the ratings table based on movie counts by median ratings.
select median_rating,count(movie_id) as no_of_movies from ratings
group by median_rating
order by no_of_movies desc;

-- Identify the production house that has produced the most number of hit movies (average rating > 8).
select production_company,count(id) as count_movies from
(select m.id,m.production_company,r.avg_rating from movies m join
ratings r on m.id=r.movie_id
where m.production_company is not null
and r.avg_rating>8) t
group by production_company
order by count(id) desc
limit 1
;

-- Determine the number of movies released in each genre during March 2017 in the USA with more than 1,000 votes.
with genre_movie_rating_cte as
(select m.id,m.year,month(m.date_published) as month,m.country,g.genre,r.total_votes from movies m join
genre g on m.id=g.movie_id join
ratings r on g.movie_id=r.movie_id)

select genre,count(id) as movie_count
from genre_movie_rating_cte
where year=2017 and month=3 and country like '%USA%' and total_votes>1000
group by genre order by movie_count desc;

-- Retrieve movies of each genre starting with the word 'The' and having an average rating > 8.
/*using cte*/
with genre_ratings_cte as
(select m.id,m.title,g.genre,r.avg_rating from movies m join
genre g on m.id=g.movie_id join
ratings r on g.movie_id=r.movie_id)

select title,avg_rating,group_concat(genre) as genre from genre_ratings_cte
where title like 'The%'
and avg_rating>8
group by title,avg_rating
order by avg_rating desc;

/*simple join*/


select m.id,m.title,g.genre,r.avg_rating from movies m join
genre g on m.id=g.movie_id join
ratings r on g.movie_id=r.movie_id
where m.title like 'The%'
and r.avg_rating>8
order by r.avg_rating desc;

-- Segment 5: Crew Analysis

-- Identify the columns in the names table that have null values.
select column_name from information_schema.columns
where table_name="names"
and table_schema="imdb"
and is_nullable="YES";


-- Determine the top three directors in the top three genres with movies having an average rating > 8.
-- genre,ratings

with cte_2 as
(select g.movie_id,g.genre,r.avg_rating,r.total_votes from genre g join ratings r 
on g.movie_id=r.movie_id),

cte_3 as
(select genre, round(sum(avg_rating*total_votes)/sum(total_votes),1) as new_avg_rating
from cte_2 group by genre
order by new_avg_rating desc
limit 3),

cte_4 as
(select n.name, round(sum(r.avg_rating*r.total_votes)/sum(r.total_votes),1) as new_avg_rating,g.genre from director_mapping d join
names n on n.id=d.name_id join ratings r on
r.movie_id=d.movie_id join genre g on g.movie_id=d.movie_id
where g.genre in (select genre from cte_3)
group by n.name,g.genre
order by new_avg_rating desc)

select * from
(select genre,name, new_avg_rating, row_number()
over(partition by genre order by new_avg_rating desc) as rank_director
from cte_4 ) t
where rank_director<=3;




-- Find the top two actors whose movies have a median rating >= 8.
with top_2_actors as
(select rm.movie_id,rm.name_id,n.name from role_mapping rm join
names n on rm.name_id=n.id 
where rm.movie_id in (select movie_id from ratings where median_rating>=8)
and rm.category="actor")

select name, count(*) as movie_count 
from top_2_actors group by name order by movie_count desc limit 10;

-- Identify the top three production houses based on the number of votes received by their movies.
select m.production_company, sum(r.total_votes) as vote_count, 
rank() over(order by sum(r.total_votes) desc) as prod_comp_rank
from movies m join ratings r on 
m.id=r.movie_id 
group by m.production_company
order by vote_count desc 
limit 3;

-- Rank actors based on their average ratings in Indian movies released in India.

select n.name,t.total_votes,t.avg_rating,t.movie_count,dense_rank() over(order by avg_rating desc) as actor_rank from names n join 
(select rm.name_id,sum(r.total_votes) as total_votes,round(sum(r.avg_rating*r.total_votes)/sum(r.total_votes),1) as avg_rating,
count(rm.movie_id) as movie_count from role_mapping rm join 
 ratings r on rm.movie_id=r.movie_id join
 names n on n.id=rm.name_id join movies m
 on m.id=r.movie_id
 where country like '%India%'
 and rm.category="actor"
 group by rm.name_id
 order by avg_rating desc) t
 on n.id=t.name_id;
 
 
-- Identify the top five actresses in Hindi movies released in India based on their average ratings.

with cte as
(select rm.name_id,sum(r.total_votes) as total_votes,round(sum(r.avg_rating*r.total_votes)/sum(r.total_votes),1) as avg_rating,
count(rm.movie_id) as movie_count from role_mapping rm join 
 ratings r on rm.movie_id=r.movie_id join
 names n on n.id=rm.name_id join movies m
 on m.id=r.movie_id
 where country like '%India%' and languages like "%Hindi%"
 and rm.category="actress"
 group by rm.name_id
 order by avg_rating desc) 
 
 select n.name, cte.total_votes, cte.avg_rating,cte.movie_count,
 row_number() over(order by cte.avg_rating desc) as actress_rank
 from cte join
 names n on cte.name_id=n.id
 where cte.movie_count>1
 limit 5 ;



-- Segment 6: Broader Understanding of Data

-- Classify thriller movies based on average ratings into different categories.
with cte_thriller as
(select g.movie_id, m.title,g.genre,r.avg_rating from genre g join ratings r
on g.movie_id=r.movie_id join movies m
on m.id=r.movie_id
where g.genre="Thriller"
order by r.avg_rating desc)

select movie_id,title,genre,avg_rating, case when avg_rating>8 then "SuperHit"
		       when avg_rating between 7 and 8 then "Hit"
               when avg_rating between 5 and 6.9 then "One time watch"
               else "Flop"
		end as Category
from cte_thriller
;


-- analyse the genre-wise running total and moving average of the average movie duration
with cte as
(select g.genre,avg(m.duration) as avg_duration from genre g join movies m 
on g.movie_id=m.id
group by g.genre)

select *,round(sum(avg_duration) over( order by genre  rows between unbounded preceding and current row),2) as running_total_duration, 
round(avg(avg_duration) over(order by genre rows between unbounded preceding and current row),2) as moving_average_duration 
from cte;

-- Identify the five highest-grossing movies of each year that belong to the top three genres.
with cte_1 as
(select genre,count(movie_id) movie_count 
from genre group by genre 
order by movie_count desc limit 3) ,

 cte_2 as
(select g.genre,m.year,m.title,m.worlwide_gross_income,
dense_rank() over(partition by g.genre,m.year order by m.worlwide_gross_income desc ) as movie_rank
from movies m join genre g 
on m.id=g.movie_id
where m.worlwide_gross_income is not null 
and genre in (select genre from cte_1)
)

select * from cte_2 where movie_rank<=5
order by genre,year,movie_rank
; 


-- Determine the top two production houses that have produced the highest number of hits among multilingual movies.

with cte_1 as
(select m.id,m.production_company,m.languages,r.avg_rating from movies m 
left join ratings r on
m.id=r.movie_id
where locate(',',languages)>0 and m.production_company is not null) 


select production_company,sum(avg_rating>8) as count_hit_movies
from cte_1 group by production_company
order by count_hit_movies desc
limit 2;

-- Identify the top three actresses based on the number of Super Hit movies (average rating > 8) in the drama genre.
with cte_1 as
(select g.movie_id,g.genre,rm.name_id,n.name,rm.category from genre g join role_mapping rm
on g.movie_id=rm.movie_id join 
names n on n.id=rm.name_id
where g.genre="Drama" and rm.category="actress"),

cte_2 as
(select c.*,r.avg_rating,r.total_votes
from cte_1 c join ratings r 
on c.movie_id=r.movie_id),

cte_3 as
(select name as actress_name,sum(total_votes) as total_votes,count(movie_id) as movie_count,
round(sum(avg_rating*total_votes)/sum(total_votes),1) as actress_avg_rating
from cte_2 group by actress_name
order by actress_avg_rating desc)

select t.*,dense_rank() over(order by actress_avg_rating desc,total_votes desc) as actress_rank
from cte_3 t  limit 3
;

-- Retrieve details for the top nine directors based on the number of movies, including average inter-movie duration, ratings, and more.
with top_director as
(select d.name_id,n.name as director_name ,count(movie_id) movie_count from director_mapping d left join
names n on n.id=d.name_id group by d.name_id,n.name
order by movie_count desc limit 9),

cte_1 as
(select d.name_id,sum(r.total_votes) as total_votes,
round(sum(r.avg_rating*r.total_votes)/sum(r.total_votes),1) as avg_rating,
min(avg_rating) min_avg_rating,max(avg_rating) as max_avg_rating
 from ratings r  right join director_mapping d
on r.movie_id=d.movie_id
where d.name_id in (select name_id from top_director)
group by d.name_id order by total_votes desc,avg_rating desc),

cte_2 as
(select a.name_id,a.director_name,a.movie_count,b.total_votes,b.avg_rating from top_director a join
cte_1 b on a.name_id=b.name_id),

cte_3 as
(select d.movie_id,d.name_id,m.date_published,m.duration,
lead(m.date_published) over(partition by d.name_id order by m.date_published desc) as next_movie_date,
datediff(m.date_published,lead(m.date_published) over(partition by d.name_id order by m.date_published desc)) as gap_between_movies
from director_mapping d left join movies m
on d.movie_id=m.id
where d.name_id in (select name_id from top_director)),

cte_4 as
(select name_id, round(avg(gap_between_movies),0) as avg_inter_movie_duration,sum(duration) as total_duration from  cte_3  
group by name_id)


select a.*,b.avg_inter_movie_duration,c.max_avg_rating,c.min_avg_rating , b.total_duration from cte_2 a join cte_4 b on
a.name_id=b.name_id join cte_1 c on b.name_id=c.name_id
order by avg_rating desc
;

/* ANALYSIS ON INDIAN MOVIES*/

/*Retrieve the Genre of Indian movies in Indian languages  avg_rating wise*/
with cte as
(select m.id,g.genre,m.country,m.languages,r.avg_rating,r.total_votes 
from genre g join movies m on g.movie_id=m.id 
join ratings r on r.movie_id=m.id
where m.country like "%India%" and languages like "%Hindi%")

select genre,count(id) as movie_count,sum(total_votes) as total_votes,
round(sum(avg_rating*total_votes)/sum(total_votes),1) as avg_rating
from cte group by genre
order by total_votes desc,avg_rating desc;


-- Determine the top three indian directors in the top three genres with movies having an average rating > 8.
with cte_2 as
(select g.movie_id,g.genre,r.avg_rating,r.total_votes from genre g join ratings r 
on g.movie_id=r.movie_id join movies m on m.id=g.movie_id
where m.country like "%India%" and m.languages like "%Hindi%"),

cte_3 as
(select genre, round(sum(avg_rating*total_votes)/sum(total_votes),1) as new_avg_rating
from cte_2 group by genre
order by new_avg_rating desc
limit 3),

cte_4 as
(select n.name, round(sum(r.avg_rating*r.total_votes)/sum(r.total_votes),1) as new_avg_rating,g.genre from director_mapping d join
names n on n.id=d.name_id join ratings r on
r.movie_id=d.movie_id join genre g on g.movie_id=d.movie_id
where g.genre in (select genre from cte_3)
group by n.name,g.genre
order by new_avg_rating desc)

select * from
(select genre,name as director_name, new_avg_rating, row_number()
over(partition by genre order by new_avg_rating desc) as rank_director
from cte_4 ) t
where rank_director<=3;

/* Highest grossing Indian multilingual movies with genre */

with genre_ratings_cte as
(select m.id,m.title,g.genre,r.avg_rating,r.total_votes from movies m join
genre g on m.id=g.movie_id join
ratings r on g.movie_id=r.movie_id
where m.country like "%India%" and languages like "%Hindi%"
and locate(',',languages)>0),

cte as
(select id,title,avg_rating,group_concat(genre) as genre,
round(sum(avg_rating*total_votes)/sum(total_votes),1) as final_avg_rating 
from genre_ratings_cte
where avg_rating>8
group by id,title,avg_rating
order by avg_rating desc)

select m.production_company,c.title,c.genre,m.languages,c.final_avg_rating,m.worlwide_gross_income from cte c join movies m on
m.id=c.id where m.worlwide_gross_income is not null
order by c.final_avg_rating,m.worlwide_gross_income desc ;



-- Segment 7: Recommendations


/* IMDb_movies in the year 2017-2019 analysis

/* KEY INSIGHTS:
GENRE:
     1.Drama,Action and Comedy are the genre which have the highest rating with highest total_votes and most number of movies
     which have released in the last three years.
DIRECTOR:     
	1.Pradeep Kalipurayath,Michael Matteo Rossi and Prithvi Konanurare are the top 3 directors in crime genre with the highest rate.
    2.Harley Wallen,Aaron K. Carter and Anand Gandhi are the top 3 directors in Horror with the highest rate. 
ACTOR:
	1.Shilpa Mahendar,Gopi Krishna and Priyanka Augustin are top 3 actors in the last 3 years with rating 9.7.
ACTRESS:
	1.Radhika Apte and Yami Gautam are the top actress with 8.4 ratings each and  Mrunal Thakur is the 2nd best actress with 8.1 rating.
    2.In Drama genre Sangeetha Bhat is the best actress with highest rating of 9.6.
PRODUCTION COMPANY:
	1. Best Production company in last 3 years is Arka Mediaworks which made movie like Baahubali 2: The Conclusion with gross_income $ 254158390.
    2. Andhadhun is the 2nd highest grossing movie in the last 3 years with gross_income $ 49391206 which was made by the production company 
    Matchbox Pictures.
BEST MOVIES:
	1.Baahubali 2: The Conclusion is the Drama,Action movie which is a multiligual movie with gross_income $ 254158390 in the year 2017
    2.Andhadhun is a Thriller,Crime movie which is made in Hindi and English languages and made gross income $ 49391206 worldwide in the year 2018.

RECOMMENDATION:
	Based on the above analysis,
    *Indian people are more likely into Drama,Action,Comedy and Thriller genre. Movies like Bahubali and Andhadhun are
    based on  genre like drama,action and Thriller.Clearly we can analysis that this kind of movies make more income then the other genre movies.
    *India is a very diverse country with lots of languages.So it is best to release movies in multiple languages so that movies could be watched
    enjoyed all over the India.It will help the Production Company to make more income.
    *By this analysis and the past reviews,indian production should cast talented actors like Shilpa Mahendar,Gopi Krishna and Priyanka Augustin
    and talented actress like Radhika Apte,Yami Gautam and Sangeetha Bhat in their movies as their main cast. 







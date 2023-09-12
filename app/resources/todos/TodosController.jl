module TodosController
using TodoMVC.Todos
using TodoMVC.ViewHelper
using Genie.Renderers, Genie.Renderers.Html
using SearchLight.Validation

using SearchLight ## give access to all, save, etc
using Genie.Router ## give access to redirect
using Genie.Renderers.Json ## give access to json
using Genie.Requests ## give access to params

function count_todos()
    notdonetodos = count(Todo, completed = false)
    donetodos = count(Todo, completed = true)
    (
    notdonetodos = notdonetodos,
    donetodos = donetodos,   
    alltodos = notdonetodos + donetodos
    )
end

function todos()
    todos = if params(:filter, "") == "done"
        find(Todo, completed = true)
    elseif params(:filter, "") == "notdone"
        find(Todo, completed = false)
    else
        all(
            Todo;
            limit = params(:limit, SearchLight.SQLLimit_ALL) |> SQLLimit,
            offset = (parse(Int, params(:page, "1")) - 1) * parse(Int, params(:limit, "0")),
        )
    end
end

function index()  
    html(:todos, :index; todos=todos(), count_todos()..., ViewHelper.active)
end
  

# function index()
#     html(:todos, :index; todos= all(Todo))
# end

function create()
    todo = Todo(todo = params(:todo)) ## link with input name in _form.jl.html

    validator = validate(todo)
    if haserrors(validator) 
      return redirect("/?error=$(errors_to_string(validator))")
    end

    if save(todo)
      redirect("/?success=Todo created")
    else
      redirect("/?error=Could not save todo&todo=$(params(:todo))")
    end
  
end

function toggle()
    todo = findone(Todo, id = params(:id))
    if todo === nothing
        return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
    end

    todo.completed = ! todo.completed

    save(todo) && json(:todo => todo)
end
  # Build something great

function update()
    todo = findone(Todo, id = params(:id))
    
    if todo === nothing
        return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
    end

    @show jsonpayload("todo")
    todo.todo = replace(jsonpayload("todo"), "<br>"=>"")
    validator = validate(todo)

    if haserrors(validator)
        return redirect("/?error=$(errors_to_string(validator))")
    end

    save(todo) && json(todo)
end

function delete()
    todo = findone(Todo, id = params(:id))
    if todo === nothing
      return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
    end
  
    SearchLight.delete(todo)
  
    json(Dict(:id => (:value => params(:id))))
end

module API
module V1

using TodoMVC.Todos
using Genie.Router
using Genie.Renderers.Json
using ....TodosController

using Genie.Requests
using SearchLight.Validation
using SearchLight

function check_payload(payload = Requests.jsonpayload())
    isnothing(payload) && throw(
        JSONException(status = BAD_REQUEST, message = "Invalid JSON message received"),
    )
    @show payload
    payload
end


function persist(todo)
    validator = validate(todo)
    if haserrors(validator)
        return JSONException(status = BAD_REQUEST, message = errors_to_string(validator)) |> json
    end

    try
        if ispersisted(todo)
            save!(todo)
            json(todo, status = OK)
        else
            save!(todo)
            json(
                todo,
                status = CREATED,
                headers = Dict("Location" => "/api/v1/todos/$(todo.id)"),
            )
        end
    catch ex
        JSONException(status = INTERNAL_ERROR, message = string(ex)) |> json
    end
end

function list()
    TodosController.todos() |> json
    # all(Todo) |> jsoxn
end

function item()
    todo = findone(Todo, id = params(:id))
    if todo === nothing
        return JSONException(status = NOT_FOUND, message = "Todo not found") |> json
    end

    todo |> json
end

function create()
    payload = try
        check_payload()
    catch ex
        return json(ex)
    end

    todo =
        Todo(todo = get(payload, "todo", ""), completed = get(payload, "completed", false))
    persist(todo)
end

function update()
    payload = try
        check_payload()
    catch ex
        return json(ex)
    end

    todo = findone(Todo, id = params(:id))
    if todo === nothing
        return JSONException(status = NOT_FOUND, message = "Todo not found") |> json
    end

    todo.todo = get(payload, "todo", todo.todo)
    todo.completed = get(payload, "completed", todo.completed)

    persist(todo)
end

function delete()
    todo = findone(Todo, id = params(:id))
    if todo === nothing
        return JSONException(status = NOT_FOUND, message = "Todo not found") |> json
    end

    try
        SearchLight.delete(todo) |> json
    catch ex
        JSONException(status = INTERNAL_ERROR, message = string(ex)) |> json
    end
end


end # V1
end # API



end
